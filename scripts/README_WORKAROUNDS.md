# CSM Pre-Upgrade Workarounds - Quick Start Guide

## Overview

This directory contains automated workarounds and comprehensive documentation for preparing a CSM 1.6.2 system for upgrade to CSM 1.7.0.

## Files

### 1. `pre_upgrade_workarounds.sh`
**Automated workaround script** that addresses identified pre-upgrade issues.

**Features:**
- Automated HSM database cleanup
- Switch credential validation
- Pod health investigation
- MetalLB status verification
- Kafka CRD preparation
- Slingshot backup verification
- Comprehensive logging

**Usage:**
```bash
chmod +x pre_upgrade_workarounds.sh
./pre_upgrade_workarounds.sh
```

### 2. `CSM_PreUpgrade_Workarounds_Guide.md`
**Comprehensive documentation** explaining each issue, its impact, and detailed workarounds.

**Sections:**
- Issue descriptions and impact analysis
- Step-by-step manual workarounds
- Command references
- Troubleshooting guidance
- Pre-upgrade verification checklist

## Quick Start

### Step 1: Backup Critical Data

```bash
# Backup HSM database
kubectl exec -n spire $(kubectl get pods -n spire -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- \
  pg_dump -U postgres hsm | gzip > /backup/hsm_backup_$(date +%Y%m%d).sql.gz

# Backup Vault data
kubectl exec -n vault $(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}') -- \
  vault operator raft snapshot save /tmp/vault_backup_$(date +%Y%m%d).snap
```

### Step 2: Document System State

```bash
mkdir -p /pre-upgrade-state
kubectl get pods -A > /pre-upgrade-state/pods_before.txt
kubectl get nodes -o wide > /pre-upgrade-state/nodes_before.txt
kubectl get svc -A > /pre-upgrade-state/services_before.txt
kubectl get pvc -A > /pre-upgrade-state/pvcs_before.txt
```

### Step 3: Run Workarounds

```bash
./pre_upgrade_workarounds.sh 2>&1 | tee pre_upgrade_workarounds_run.log
```

### Step 4: Review Results

```bash
# Check exit code (0 = success, 1 = failures, 2 = skipped items needing manual intervention)
echo "Exit code: $?"

# Review detailed logs
tail -100 /var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log

# Check specific issues
grep "FAILED\|WARNING" /var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log
```

### Step 5: Manual Verification

Reference the "Manual Intervention Checklist" in `CSM_PreUpgrade_Workarounds_Guide.md` to verify all pre-upgrade requirements are met.

## Issues Addressed

| # | Issue | Status | Manual? |
|---|-------|--------|---------|
| 1 | HSM Duplicate Events | Automated | No |
| 2 | Switch Admin Password | Automated | Yes* |
| 3 | CrashLoopBackOff Pods | Diagnostic | Yes |
| 4 | MetalLB IP Allocation | Diagnostic | Yes |
| 5 | Kafka CRD | Verified | No |
| 6 | Slingshot Backups | Verified | No |
| 7 | Pod Restart Counts | Diagnostic | Yes |
| 8 | Vault Operator CRD | Verified | No |
| 9 | PostgreSQL CRD | Verified | No |
| 10 | Network Services | Verified | No |

*Requires manual credential entry or script execution

## Output Example

```
╔════════════════════════════════════════════════════════════════╗
║  CSM Pre-Upgrade Workarounds Script                            ║
║  Target: CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)               ║
║  Date: 2026-02-18 14:30:00                                     ║
╚════════════════════════════════════════════════════════════════╝

[FIX 1] HSM Duplicate Detected Events Cleanup
✓ APPLIED: HSM duplicate detected events cleaned up

[FIX 2] Switch Admin Password Vault Configuration
ℹ INFO: Switch admin password already configured in vault
⊘ SKIPPED: Switch admin password already exists

[FIX 3] CrashLoopBackOff Pods Investigation and Cleanup
⚠ WARNING: Found 2 pod(s) in CrashLoopBackOff state
ℹ INFO: Pod investigation logged

========================================
Pre-Upgrade Workarounds Summary
========================================

Total Fixes: 10
✓ Applied: 8
⊘ Skipped: 2
✗ Failed: 0

Log file: /var/log/cray/csm/upgrade/pre_upgrade_workarounds_20260218_143000.log
```

## Troubleshooting

### Script Fails to Execute

```bash
# Verify permissions
ls -la pre_upgrade_workarounds.sh

# Make executable if needed
chmod +x pre_upgrade_workarounds.sh

# Check for bash syntax errors
bash -n pre_upgrade_workarounds.sh
```

### kubectl Not Found

```bash
# Verify kubectl is available
which kubectl

# Add to PATH if needed
export PATH=$PATH:/usr/local/bin

# Or use full path
/usr/bin/kubectl get pods -A
```

### Permission Denied Errors

```bash
# Verify cluster access
kubectl auth can-i get pods --all-namespaces

# Check current context
kubectl config current-context

# Verify admin credentials
kubectl get nodes
```

## Key Log Files

| Location | Purpose |
|----------|---------|
| `/var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log` | Main script output |
| `/var/backups/cray/csm/upgrade/` | Backup data |
| `/tmp/hsm_cleanup_duplicates.sql` | HSM cleanup SQL (temporary) |

## References

- **CSM Documentation:** https://github.com/Cray-HPE/docs-csm/tree/main/upgrade/
- **Pre-Upgrade Checks Script:** `pre_upgrade_new_checks.sh`
- **Upgrade Main Guide:** CSM 1.6 to 1.7 Migration

## Next Steps After Workarounds

1. ✅ Review and verify all workaround results
2. ✅ Complete manual intervention checklist
3. ✅ Verify system health with pre_upgrade_new_checks.sh
4. ✅ Create final backup before upgrade
5. ✅ Begin CSM 1.7 upgrade procedures

## Support

For issues or questions:

1. Check `/var/log/cray/csm/upgrade/pre_upgrade_workarounds_*.log`
2. Review `CSM_PreUpgrade_Workarounds_Guide.md` section for specific issue
3. Consult CSM documentation and support team
4. Do not proceed with upgrade if critical issues remain

---

**Version:** 1.0  
**Last Updated:** February 18, 2026  
**Target:** CSM 1.6.2 → CSM 1.7.0
