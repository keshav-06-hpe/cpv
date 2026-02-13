# Pre-Upgrade Script Enhancement Guide

## Using CSM Official Documentation to Improve Pre-Upgrade Checks

This guide shows how to leverage the official CSM documentation repository to enhance the pre-upgrade check script with real CSM command references and validation procedures.

## Quick Reference: Script Checks → CSM Documentation

| Check Category | Script Function | CSM Documentation Reference |
|----------------|----------------|----------------------------|
| **Active IUF Sessions** | `check_csm_issues()` | `operations/iuf/IUF.md` |
| **Nexus Space** | `check_csm_issues()` | `operations/package_repository_management/nexus_space_cleanup/` |
| **Kafka CRD** | `check_csm_issues()` | `troubleshooting/scripts/kafka_crd_fix.sh` |
| **BOS Sessions** | `check_system_prerequisites()` | `operations/boot_orchestration/` |
| **CFS Sessions** | `check_system_prerequisites()` | `operations/configuration_management/` |
| **Helm Releases** | `check_sma_issues()` | `troubleshooting/known_issues/helm_chart_deploy_timeouts.md` |
| **OpenSearch Pods** | `check_sma_issues()` | SMA-specific troubleshooting |
| **Kafka Topics** | `check_sma_issues()` | SMA Kafka configuration |
| **Switch Passwords** | `check_system_prerequisites()` | `operations/network/management_network/` |
| **HSM Duplicates** | `check_system_prerequisites()` | `operations/hardware_state_manager/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md` |

## Enhanced Checks Based on CSM Documentation

### 1. Kubernetes Health Validation

**Documentation:** `operations/validate_csm_health/`

```bash
# Add to pre-upgrade script
check_kubernetes_health() {
    print_header "Kubernetes Cluster Health"
    
    # Check node status (from CSM health validation)
    print_check "Checking Kubernetes node status"
    NOT_READY=$(kubectl get nodes | grep -v Ready | grep -v NAME | wc -l)
    if [ "$NOT_READY" -gt 0 ]; then
        print_fail "$NOT_READY nodes not in Ready state"
        kubectl get nodes | grep -v Ready | grep -v NAME
    else
        print_pass "All Kubernetes nodes Ready"
    fi
    
    # Check critical pods (from CSM documentation)
    print_check "Checking critical system pods"
    CRITICAL_NAMESPACES="kube-system services nexus vault"
    for ns in $CRITICAL_NAMESPACES; do
        FAILED_PODS=$(kubectl get pods -n $ns 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
        if [ "$FAILED_PODS" -gt 0 ]; then
            print_warning "Found $FAILED_PODS non-running pods in namespace $ns"
        fi
    done
}
```

### 2. Ceph Storage Health

**Documentation:** `operations/utility_storage/`

```bash
check_ceph_health() {
    print_header "Ceph Storage Health"
    
    # Check Ceph cluster status
    print_check "Checking Ceph cluster health"
    if command -v ceph &> /dev/null; then
        CEPH_STATUS=$(ceph health 2>/dev/null | awk '{print $1}')
        case "$CEPH_STATUS" in
            "HEALTH_OK")
                print_pass "Ceph cluster health: OK"
                ;;
            "HEALTH_WARN")
                print_warning "Ceph cluster health: WARNING"
                ceph health detail
                ;;
            "HEALTH_ERR"|*)
                print_fail "Ceph cluster health: ERROR or UNKNOWN"
                ceph health detail
                ;;
        esac
    else
        print_warning "ceph command not available"
    fi
    
    # Check OSD status
    print_check "Checking Ceph OSD status"
    DOWN_OSDS=$(ceph osd stat 2>/dev/null | grep -oP '\d+ down' | awk '{print $1}')
    if [ -n "$DOWN_OSDS" ] && [ "$DOWN_OSDS" -gt 0 ]; then
        print_fail "$DOWN_OSDS OSDs are down"
    else
        print_pass "All OSDs are up"
    fi
}
```

### 3. Spire Health Check

**Documentation:** `operations/spire/` and `troubleshooting/known_issues/spire_*.md`

```bash
check_spire_health() {
    print_header "Spire Service Health"
    
    # Check Spire pods
    print_check "Checking Spire pod status"
    SPIRE_PODS=$(kubectl get pods -n spire 2>/dev/null | grep spire-server | grep -v Running | wc -l)
    if [ "$SPIRE_PODS" -gt 0 ]; then
        print_fail "Spire server pods not running properly"
        kubectl get pods -n spire | grep spire-server
    else
        print_pass "Spire server pods healthy"
    fi
    
    # Check for common Spire issues from known_issues
    print_check "Checking for known Spire issues"
    INITIALIZING=$(kubectl get pods -n spire 2>/dev/null | grep PodInitializing | wc -l)
    if [ "$INITIALIZING" -gt 0 ]; then
        print_warning "Spire pods stuck in PodInitializing state"
        log_message "       See: troubleshooting/known_issues/spire_pod_initializing.md"
    fi
}
```

### 4. Validate CSM Health Script Integration

**Documentation:** `operations/validate_csm_health/`

```bash
check_csm_services_health() {
    print_header "CSM Core Services Health"
    
    # HMS services
    print_check "Checking HMS services"
    HMS_SERVICES="cray-hms-discovery cray-smd cray-sls"
    for svc in $HMS_SERVICES; do
        REPLICAS=$(kubectl get deployment -n services $svc -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
        DESIRED=$(kubectl get deployment -n services $svc -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ "$REPLICAS" != "$DESIRED" ]; then
            print_warning "$svc: $REPLICAS/$DESIRED replicas available"
        fi
    done
    
    # BSS (Boot Script Service)
    print_check "Checking BSS (Boot Script Service)"
    BSS_STATUS=$(kubectl get pods -n services -l app.kubernetes.io/name=cray-bss 2>/dev/null | grep -v NAME | grep Running | wc -l)
    if [ "$BSS_STATUS" -eq 0 ]; then
        print_fail "BSS pods not running"
    else
        print_pass "BSS is running"
    fi
}
```

### 5. Network Services Validation

**Documentation:** `operations/network/`

```bash
check_network_services() {
    print_header "Network Services Health"
    
    # DNS
    print_check "Checking DNS services"
    DNS_PODS=$(kubectl get pods -n services -l app.kubernetes.io/name=cray-dns-unbound 2>/dev/null | grep Running | wc -l)
    if [ "$DNS_PODS" -eq 0 ]; then
        print_fail "DNS unbound pods not running"
    else
        print_pass "DNS services running"
    fi
    
    # DHCP
    print_check "Checking DHCP services"
    DHCP_PODS=$(kubectl get pods -n services -l app.kubernetes.io/name=cray-dhcp-kea 2>/dev/null | grep Running | wc -l)
    if [ "$DHCP_PODS" -eq 0 ]; then
        print_fail "DHCP kea pods not running"
    else
        print_pass "DHCP services running"
    fi
    
    # MetalLB
    print_check "Checking MetalLB IP allocation"
    UNALLOCATED=$(kubectl get svc -A 2>/dev/null | grep LoadBalancer | grep '<pending>' | wc -l)
    if [ "$UNALLOCATED" -gt 0 ]; then
        print_warning "$UNALLOCATED LoadBalancer services without allocated IPs"
        log_message "       See: operations/network/metallb_bgp/"
    fi
}
```

### 6. PostgreSQL Database Health

**Documentation:** `operations/kubernetes/Troubleshoot_Postgres_Database.md`

```bash
check_postgres_health() {
    print_header "PostgreSQL Database Health"
    
    # Check PostgreSQL clusters
    print_check "Checking PostgreSQL cluster status"
    PG_CLUSTERS=$(kubectl get postgresql -A 2>/dev/null | grep -v NAME | awk '{print $1":"$2}')
    
    for cluster in $PG_CLUSTERS; do
        ns=$(echo $cluster | cut -d: -f1)
        name=$(echo $cluster | cut -d: -f2)
        
        RUNNING=$(kubectl get pods -n $ns -l application=spilo,cluster-name=$name 2>/dev/null | grep Running | wc -l)
        TOTAL=$(kubectl get postgresql -n $ns $name -o jsonpath='{.spec.numberOfInstances}' 2>/dev/null)
        
        if [ "$RUNNING" != "$TOTAL" ]; then
            print_warning "PostgreSQL $ns/$name: $RUNNING/$TOTAL instances running"
        fi
    done
    
    # Check for known PostgreSQL issues
    print_check "Checking for known PostgreSQL issues"
    log_message "       Review: troubleshooting/known_issues/postgres_*.md"
}
```

### 7. CSM 1.7 Specific Pre-Checks

**Documentation:** `troubleshooting/known_issues/` and `introduction/csi_Tool_Changes.md`

```bash
check_csm_17_specific() {
    print_header "CSM 1.7 Specific Pre-Checks"
    
    # Check for Cilium readiness (CSM 1.7 migration)
    print_check "Checking current CNI (Weave → Cilium migration in 1.7)"
    CURRENT_CNI=$(kubectl get pods -n kube-system 2>/dev/null | grep -c weave)
    if [ "$CURRENT_CNI" -gt 0 ]; then
        print_info "Currently running Weave CNI - will be migrated to Cilium during upgrade"
        log_message "       See: troubleshooting/known_issues/cilium_migration_*.md"
    fi
    
    # Check BSS global metadata for Cilium migration
    print_check "Checking BSS global metadata for Cilium migration"
    # This requires BSS API access - example placeholder
    print_info "Verify k8s_primary_cni is set in BSS global metadata"
    log_message "       Required for: Cilium Migration Failure prevention"
    
    # CSI tool behavior changes
    print_check "Checking for CSI tool configuration"
    if [ -f "/etc/cray/csi/config.yaml" ]; then
        print_info "CSI configuration found - review for version 1.7 changes"
        log_message "       See: introduction/csi_Tool_Changes.md"
    fi
}
```

## CSM Command Reference for Checks

### Essential Commands from CSM Documentation

```bash
# Health Validation Commands
# Reference: operations/validate_csm_health/

# 1. Check all pods across namespaces
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# 2. Check node status
kubectl get nodes

# 3. Check Ceph health
ceph -s
ceph health detail
ceph osd df tree

# 4. Check services with external IPs
kubectl get svc -A | grep LoadBalancer

# 5. Check for certificate issues
kubectl get certificaterequests -A

# 6. Validate HMS
cray hsm state components list --format json

# 7. Check BOS sessions
cray bos sessions list --format json

# 8. Check CFS sessions  
cray cfs sessions list --format json

# 9. IUF activity status
iuf list
iuf activity describe <activity-name>

# 10. Argo workflow status
kubectl get workflows -n argo
```

### Troubleshooting Commands

```bash
# From troubleshooting/kubernetes/

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check persistent volume claims
kubectl get pvc -A

# Check etcd health
kubectl exec -n kube-system etcd-<node> -- etcdctl endpoint health

# Check for stuck resources
kubectl get all -A | grep -i terminating
```

## Integration Strategy

### Phase 1: Basic Integration (Current)
✅ Already implemented in `pre_upgrade_checks.sh`:
- Basic Kubernetes checks
- Nexus space validation
- Session checks (BOS, CFS, IUF)
- Helm release status

### Phase 2: Enhanced Integration (Recommended)
Add from CSM documentation:
- Ceph health validation
- PostgreSQL cluster status
- Spire service health
- Network services validation
- HMS service checks

### Phase 3: Advanced Integration
Leverage CSM scripts:
- Import actual health check scripts
- Use CSM validation procedures
- Integrate with Argo workflows
- Add product-specific validations

## Example: Enhanced Check Function

Here's how to enhance the existing script with CSM documentation references:

```bash
check_csm_issues() {
    print_header "CSM Core Issues"
    
    # Reference: operations/iuf/IUF.md
    print_check "Checking for active IUF sessions"
    if command -v iuf &> /dev/null; then
        # Use actual IUF command from documentation
        IUF_ACTIVITIES=$(iuf list --format json 2>/dev/null | jq -r '.[] | select(.state != "completed") | .name' | wc -l)
        if [ "$IUF_ACTIVITIES" -gt 0 ]; then
            print_fail "Found $IUF_ACTIVITIES active IUF activities"
            log_message "       Run 'iuf list' to see active activities"
            log_message "       Reference: operations/iuf/IUF.md"
            log_message "       Related: CAST-38971 (IUF stage progression issues)"
        else
            print_pass "No active IUF activities found"
        fi
    else
        print_warning "IUF command not found, cannot verify IUF state"
        log_message "       Install IUF: operations/iuf/IUF.md#installation"
    fi
    
    # Reference: operations/package_repository_management/nexus_space_cleanup/
    print_check "Checking Nexus storage space"
    if command -v kubectl &> /dev/null; then
        NEXUS_USAGE=$(kubectl exec -n nexus deployment/nexus -c nexus -- df -h /nexus-data 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
        NEXUS_THRESHOLD=80
        
        if [ "$NEXUS_USAGE" -gt "$NEXUS_THRESHOLD" ]; then
            print_fail "Nexus storage at ${NEXUS_USAGE}% (threshold: ${NEXUS_THRESHOLD}%)"
            log_message "       Cleanup procedure:"
            log_message "       https://github.com/Cray-HPE/docs-csm/blob/release/1.7/operations/package_repository_management/nexus_space_cleanup/"
            log_message "       Related: CASMTRIAGE-8826"
        else
            print_pass "Nexus storage at ${NEXUS_USAGE}% (acceptable)"
        fi
    fi
    
    # Reference: troubleshooting/scripts/kafka_crd_fix.sh
    print_check "Validating Kafka CRD configuration"
    if [ -f "/usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh" ]; then
        print_info "Kafka CRD fix script available"
        log_message "       Run if needed: /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh"
        log_message "       Reference: upgrade/Prepare_for_Upgrade_to_Next_CSM_Major_Version.md#3-fix-kafka-crd-issue"
    else
        print_warning "Kafka CRD fix script not found - install latest CSM docs package"
    fi
}
```

## Testing and Validation

### Test on Non-Production System
1. Clone CSM documentation repo
2. Review actual commands and procedures
3. Test script against CSM environment
4. Validate against known_issues documentation
5. Compare with CSM health validation procedures

### Continuous Improvement
- Monitor CSM repository for updates
- Review new known_issues as they're added
- Update script with new validation procedures
- Test against different CSM versions

## Resources

- **CSM Docs Repository:** https://github.com/Cray-HPE/docs-csm/
- **Live Documentation:** https://cray-hpe.github.io/docs-csm/en-17/
- **Known Issues:** https://github.com/Cray-HPE/docs-csm/tree/release/1.7/troubleshooting/known_issues/
- **IUF Documentation:** https://github.com/Cray-HPE/docs-csm/tree/release/1.7/operations/iuf/
- **Upgrade Procedures:** https://github.com/Cray-HPE/docs-csm/tree/release/1.7/upgrade/

## Next Steps

1. ✅ Review CSM documentation context summary
2. ✅ Understand documentation structure
3. ⏭️ Enhance pre-upgrade script with CSM-specific checks
4. ⏭️ Add references to actual CSM documentation
5. ⏭️ Test on development CSM system
6. ⏭️ Integrate with CSM health validation procedures
7. ⏭️ Add product-specific validations (SMA, USS, Slingshot, etc.)
