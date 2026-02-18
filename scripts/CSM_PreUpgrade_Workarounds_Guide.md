# CSM Pre-Upgrade Workarounds Guide
## CSM 25.3.2 (1.6.2) to 25.9.0 (1.7.0) Upgrade Preparation

**Version:** 1.0  
**Date:** February 18, 2026  
**Target System:** CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Requisites](#pre-requisites)
3. [Issues and Workarounds](#issues-and-workarounds)
4. [Usage](#usage)
5. [References](#references)

---

## Overview

This document outlines the pre-upgrade workarounds and fixes required before upgrading from CSM 1.6.2 to CSM 1.7.0. The corresponding `pre_upgrade_workarounds.sh` script automates most of these fixes.

### Scope

This guide addresses the following issues identified in the pre-upgrade checks:

1. HSM Duplicate Detected Events
2. Switch Admin Password Configuration
3. CrashLoopBackOff Pods
4. MetalLB LoadBalancer IP Allocation Issues
5. Kafka CRD Preparation
6. Slingshot Fabric Backup Status
7. Pod Restart Count Issues
8. Vault Operator CRD Compatibility
9. PostgreSQL Operator CRD Preparation
10. Network Services Verification

---

## Pre-Requisites

### Required Tools

- `kubectl` - Kubernetes command-line tool
- `cray` - Cray CLI (for some tasks)
- `helm` - Helm package manager
- Bash shell environment
- Access to management node or admin credentials

### Required Permissions

- Kubernetes cluster admin access
- Vault access for secret management
- PostgreSQL admin credentials
- SSH access to management nodes (if needed)

### Backup Requirements

Before running any workarounds, ensure you have:

1. **PostgreSQL Database Backups**
   ```bash
   kubectl exec -n spire <postgres-pod> -- \
     pg_dump -U postgres hsm > /backup/hsm_backup_$(date +%Y%m%d).sql
   ```

2. **Vault Data Backup**
   ```bash
   kubectl exec -n vault <vault-pod> -- \
     vault operator raft snapshot save /tmp/vault_backup_$(date +%Y%m%d).snap
   ```

3. **etcd Backups** (for critical services)
   ```bash
   kubectl exec -n <namespace> <etcd-pod> -- \
     etcdctl snapshot save /tmp/etcd_backup_$(date +%Y%m%d).db
   ```

4. **System State Documentation**
   - Capture current pod status: `kubectl get pods -A > before_upgrade_pods.txt`
   - Capture node status: `kubectl get nodes -o wide > before_upgrade_nodes.txt`
   - Document Slingshot configuration
   - Document network configuration (BGP, MetalLB)

---

## Issues and Workarounds

### Issue 1: HSM Duplicate Detected Events

**Problem:** HSM database accumulates excessive duplicate "Detected" events, causing:
- Database size bloat
- Query performance degradation
- Potential upgrade failures

**Reference:** [Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md](https://github.com/Cray-HPE/docs-csm/tree/main/operations/hardware_state_manager/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md)

**Workaround:**

The script connects to the HSM PostgreSQL database and removes duplicate events:

```bash
# Automated (via script)
./pre_upgrade_workarounds.sh

# Manual method (for large databases)
kubectl exec -n spire <postgres-pod> -- psql -U postgres -d hsm << 'EOF'
BEGIN;

-- For large databases, run this faster version
DELETE FROM events e1
USING events e2
WHERE e1.component_id = e2.component_id
  AND e1.event_type = 'Detected'
  AND e1.timestamp < e2.timestamp
  AND e1.timestamp < NOW() - INTERVAL '7 days'
  AND e1.id > e2.id;

-- Analyze tables for query optimizer
ANALYZE events;

COMMIT;
EOF
```

**Verification:**
```bash
kubectl exec -n spire <postgres-pod> -- psql -U postgres -d hsm \
  -c "SELECT COUNT(*) as detected_event_count FROM events WHERE event_type='Detected';"
```

**Expected Result:** Significant reduction in duplicate events, usually 70-90% fewer events.

---

### Issue 2: Switch Admin Password Not in Vault

**Problem:** Network switch admin credentials are not stored in Vault, preventing:
- Automated switch configuration
- Switch health monitoring
- Upgrade automation

**Reference:** [Adding Switch Admin Password to Vault](https://github.com/Cray-HPE/docs-csm/tree/main/operations/network/management_network/README.md)

**Workaround:**

The script provides guidance for manual credential storage:

```bash
# Option 1: Using Python script (Recommended)
python3 /usr/share/doc/csm/scripts/operations/configuration/write_sw_admin_pw_to_vault.py

# Option 2: Using Cray CLI
cray vault kv put secret/switch-admin \
  username=<admin_username> \
  password=<admin_password>

# Option 3: Using kubectl directly
kubectl exec -n vault <vault-pod> -- vault kv put secret/switch-admin \
  username=<admin_username> \
  password=<admin_password>
```

**Verification:**
```bash
# Verify credentials are stored
cray vault kv get secret/switch-admin

# Or via kubectl
kubectl exec -n vault <vault-pod> -- vault kv get secret/switch-admin
```

---

### Issue 3: CrashLoopBackOff Pods

**Problem:** Pods stuck in CrashLoopBackOff indicate:
- Application errors or misconfigurations
- Resource constraints
- Dependency issues (database, APIs, etc.)
- Incompatible container images

**Workaround:**

The script investigates each pod and logs diagnostics:

```bash
# View pods in CrashLoopBackOff
kubectl get pods -A | grep CrashLoopBackOff

# For each problematic pod, review logs
kubectl logs -n <namespace> <pod-name> --previous

# Check pod events
kubectl describe pod -n <namespace> <pod-name>

# Check resource constraints
kubectl get pod -n <namespace> <pod-name> -o yaml | grep -A 20 resources:

# Check if service it depends on is available
kubectl get svc -n <namespace>
```

**Common Solutions:**

1. **Insufficient Resources:**
   ```bash
   # Increase resource requests if needed
   kubectl set resources deployment <name> -n <namespace> \
     --requests=cpu=500m,memory=512Mi
   ```

2. **Missing Dependency:**
   ```bash
   # Restart dependent services in correct order
   kubectl rollout restart deployment -n <namespace> <deployment-name>
   ```

3. **Configuration Error:**
   ```bash
   # Edit ConfigMap or Secret
   kubectl edit configmap -n <namespace> <configmap-name>
   kubectl rollout restart deployment -n <namespace> <deployment-name>
   ```

---

### Issue 4: MetalLB LoadBalancer Services Without IP Allocation

**Problem:** LoadBalancer services remain in `<pending>` state, preventing:
- External access to services
- Ingress functionality
- API accessibility during upgrade

**Reference:** [Troubleshoot Services without an Allocated IP Address](https://github.com/Cray-HPE/docs-csm/tree/main/operations/network/metallb_bgp/Troubleshoot_Services_without_an_Allocated_IP_Address.md)

**Workaround:**

The script checks MetalLB status and provides diagnostics:

```bash
# Check MetalLB controller status
kubectl get pods -n metallb-system

# View address pools
kubectl get addresspools -n metallb-system

# View BGP peering status
kubectl get bgppeers -n metallb-system

# Check BGP advertisements
kubectl get bgpadvertisements -n metallb-system

# View MetalLB logs
kubectl logs -n metallb-system -l app=metallb -f
```

**Common Solutions:**

1. **BGP Peer Not Connected:**
   ```bash
   # Verify BGP peer configuration
   kubectl get bgppeers -n metallb-system -o yaml
   
   # Check connectivity to BGP neighbor
   kubectl run -it --rm debug --image=busybox --restart=Never -- \
     sh -c "nc -zv <bgp_neighbor_ip> 179"
   ```

2. **Address Pool Exhausted:**
   ```bash
   # View current address pool usage
   kubectl get addresspool -n metallb-system -o yaml
   
   # Add new address pool if needed
   cat << 'EOF' | kubectl apply -f -
   apiVersion: metallb.io/v1beta1
   kind: AddressPool
   metadata:
     name: additional-pool
     namespace: metallb-system
   spec:
     addresses:
     - 10.0.0.0/24
   EOF
   ```

3. **BGP Configuration:**
   ```bash
   # Verify BGP speaker configuration
   kubectl get bgppeers -n metallb-system -o yaml
   
   # Restart metallb-controller if needed
   kubectl rollout restart deployment metallb-controller -n metallb-system
   ```

---

### Issue 5: Kafka CRD Preparation

**Problem:** Kafka CRD compatibility issues between CSM 1.6 and 1.7:
- Strimzi operator version incompatibility
- StatefulSet vs StrimziPodSet migration
- CRD schema changes

**Reference:** Kafka CRD handling in CSM 1.7 upgrade

**Workaround:**

The script verifies Kafka cluster status and operator version:

```bash
# Check Kafka CRDs
kubectl get crd | grep kafka

# Check Strimzi operator version
kubectl get deployment -n strimzi strimzi-cluster-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check Kafka cluster status
kubectl get kafka -A

# Verify kafka cluster is healthy
kubectl get kafka -n <namespace> -o yaml | grep -A 20 status:
```

**Pre-Upgrade Preparations:**

1. **Run Kafka CRD Fix Script:**
   ```bash
   /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh
   ```

2. **Verify Operator Readiness:**
   ```bash
   # Ensure Strimzi is at compatible version
   kubectl get deployment -n strimzi strimzi-cluster-operator -o yaml
   ```

3. **Monitor Kafka Pods:**
   ```bash
   kubectl get pods -n kafka -l app.kubernetes.io/component=kafka
   ```

---

### Issue 6: Slingshot Fabric Backup Status

**Problem:** Missing or failed Slingshot backups prevent:
- Fabric configuration recovery
- Safe upgrade rollback
- Disaster recovery

**Reference:** Issue 2300387

**Workaround:**

The script verifies backup infrastructure:

```bash
# Check Velero backup status
kubectl get backups -n velero

# View recent backups
kubectl get backups -n velero -A | sort -k6 | tail -5

# Check backup schedules
kubectl get schedules -n velero

# Check backup storage location
kubectl get backupstoragelocations -n velero

# Manually trigger backup
kubectl create -f - << 'EOF'
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: slingshot-fabric-backup-$(date +%Y%m%d)
  namespace: velero
spec:
  storageLocation: default
  includedNamespaces:
  - slingshot-fabric
EOF

# Monitor backup progress
kubectl get backups -n velero -w
```

**Verification:**
```bash
# Verify backup size
kubectl exec -n velero <minio-pod> -- \
  aws s3 ls s3://velero/backups/ --recursive --summarize

# Ensure recent successful backup exists
kubectl get backups -n velero -o json | \
  jq '.items[] | select(.status.phase == "Completed") | .metadata.creationTimestamp'
```

---

### Issue 7: Pod Restart Count Issues

**Problem:** Pods with excessive restarts (>50) indicate:
- Memory leaks
- Crash loops
- Resource exhaustion
- Application errors

**Workaround:**

```bash
# Find pods with high restart counts
kubectl get pods -A -o json | jq -r '.items[] | \
  select(.status.containerStatuses[0].restartCount > 50) | 
  "\(.metadata.namespace) \(.metadata.name) \(.status.containerStatuses[0].restartCount)"'

# For each pod, review logs
kubectl logs -n <namespace> <pod-name> --tail=100

# Check resource utilization
kubectl top pods -n <namespace> <pod-name>

# Adjust resource limits
kubectl set resources deployment <name> -n <namespace> \
  --requests=cpu=1,memory=1Gi --limits=cpu=2,memory=2Gi
```

---

### Issue 8: Vault Operator CRD Issues

**Problem:** Vault operator CRD incompatibility causes:
- Vault pod startup failures
- Secret management issues
- Upgrade failures

**Reference:** [cray-vault-operator Chart Upgrade Error](https://github.com/Cray-HPE/docs-csm/tree/main/troubleshooting/known_issues/cray-vault-operator_chart_upgrade_error.md)

**Workaround:**

```bash
# Check Vault CRD version
kubectl get crd vaults.vault.banzaicloud.com -o jsonpath='{.spec.names.kind}'

# Check Vault operator deployment
kubectl get deployment -n vault vault-operator -o yaml

# Verify Vault pods are running
kubectl get pods -n vault -l app=vault

# Check for CRD compatibility errors
kubectl describe crd vaults.vault.banzaicloud.com
```

---

### Issue 9: PostgreSQL Operator CRD Preparation

**Problem:** PostgreSQL operator CRD changes affect:
- Database cluster definitions
- Patroni configurations
- High availability setup

**Workaround:**

```bash
# Check PostgreSQL CRDs
kubectl get crd | grep postgresql

# List PostgreSQL clusters
kubectl get postgresql -A

# Verify cluster health
kubectl get postgresql -n <namespace> -o yaml | grep -A 10 status:

# Check Patroni cluster status
kubectl exec -n <namespace> <pod-name> -- \
  patronictl list
```

---

### Issue 10: Network Services Verification

**Problem:** DNS and network issues prevent:
- Pod-to-pod communication
- External API access
- Upgrade coordination

**Workaround:**

```bash
# Verify CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm --restart=Never --image=busybox dns-test -- \
  nslookup kubernetes.default

# Test inter-pod connectivity
kubectl run -it --rm --restart=Never --image=busybox net-test -- \
  wget -O- http://kubernetes.default.svc.cluster.local

# Check network policies
kubectl get networkpolicies -A
```

---

## Usage

### Automated Execution

```bash
# Make script executable
chmod +x /path/to/pre_upgrade_workarounds.sh

# Run with default options
./pre_upgrade_workarounds.sh

# View results
cat /var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log
```

### Script Output

The script generates:
- **Log File:** `/var/log/cray/csm/upgrade/pre_upgrade_workarounds_YYYYMMDD_HHMMSS.log`
- **Backup Directory:** `/var/backups/cray/csm/upgrade/`
- **Summary Report:** Printed to stdout and logged

### Interpreting Results

```
✓ APPLIED    - Workaround was successfully applied
⊘ SKIPPED    - Workaround was skipped (not applicable or manual intervention required)
✗ FAILED     - Workaround failed (requires manual investigation)
ℹ INFO       - Informational message
⚠ WARNING    - Warning message requiring attention
✓ SUCCESS    - Operation completed successfully
```

### Exit Codes

- `0` - All workarounds completed successfully
- `1` - Some workarounds failed
- `2` - Some workarounds skipped (may require manual intervention)

---

## Manual Intervention Checklist

Before starting the upgrade, verify:

- [ ] HSM duplicate events cleaned up (< 10K remaining)
- [ ] Switch admin password configured in Vault
- [ ] All CrashLoopBackOff pods investigated and resolved
- [ ] MetalLB services have assigned IPs
- [ ] Kafka CRD fix script executed
- [ ] Slingshot backups successful and recent (< 1 day old)
- [ ] Pod restart counts normalized
- [ ] Vault operator CRD compatible
- [ ] PostgreSQL operator CRD prepared
- [ ] DNS and network services operational
- [ ] All databases backed up
- [ ] Cluster state documented

---

## References

### CSM Documentation

- [CSM 1.7 Upgrade Guide](https://github.com/Cray-HPE/docs-csm/tree/main/upgrade/Upgrade_Management_Nodes_and_CSM_Services.md)
- [Prepare for Upgrade to Next CSM Major Version](https://github.com/Cray-HPE/docs-csm/tree/main/upgrade/Prepare_for_Upgrade_to_Next_CSM_Major_Version.md)
- [Remove Duplicate Detected Events](https://github.com/Cray-HPE/docs-csm/tree/main/operations/hardware_state_manager/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md)
- [MetalLB BGP Configuration](https://github.com/Cray-HPE/docs-csm/tree/main/operations/network/metallb_bgp/)
- [Switch Admin Password](https://github.com/Cray-HPE/docs-csm/tree/main/operations/network/management_network/README.md)
- [Vault Operator CRD Issues](https://github.com/Cray-HPE/docs-csm/tree/main/troubleshooting/known_issues/cray-vault-operator_chart_upgrade_error.md)

### Related Issues

- Issue 2300387 - Slingshot backup status
- Issue 2160777 - SLURM/PALS ranks
- Issue 3110032 - CXI service VNI updates

### Tools and Commands

- `kubectl` - Kubernetes CLI
- `cray` - Cray system management CLI
- `helm` - Package manager
- `psql` - PostgreSQL client
- `vault` - Vault CLI

---

## Support and Troubleshooting

For issues during workaround execution:

1. Check the log file: `/var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log`
2. Review the corresponding CSM documentation
3. Consult CSM support with log files and system state documentation
4. Do not proceed with upgrade if critical workarounds fail

---

## Appendix: Quick Reference

### Essential Commands

```bash
# Monitor upgrade progress
watch -n 5 'kubectl get pods -A | grep -E "CrashLoop|Pending|ContainerCreating"'

# Check system health
kubectl get nodes
kubectl get pods -A --sort-by=.metadata.creationTimestamp
kubectl get pvc -A

# Backup critical data
kubectl exec -n spire <postgres-pod> -- \
  pg_dump -U postgres hsm | gzip > hsm_backup.sql.gz

# Verify MetalLB
kubectl get svc -A | grep LoadBalancer
```

---

**Document Version:** 1.0  
**Last Updated:** February 18, 2026  
**Status:** Ready for CSM 1.7 Upgrade
