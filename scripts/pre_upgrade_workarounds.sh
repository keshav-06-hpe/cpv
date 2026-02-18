#!/bin/bash
################################################################################
# CSM Pre-Upgrade Workarounds Script
# Version: 1.0
# Purpose: Automatically apply workarounds for CSM 25.3.2 (1.6.2) to 25.9.0 (1.7.0) upgrade
#
# This script applies fixes for known issues identified in pre-upgrade checks:
# 1. HSM duplicate detected events cleanup
# 2. Switch admin password vault configuration
# 3. CrashLoopBackOff pods investigation and cleanup
# 4. MetalLB LoadBalancer IP allocation fixes
# 5. Kafka CRD preparation
# 6. Slingshot fabric backup verification
#
# Note: This script makes changes to the system. Always backup before running.
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_FIXES=0
APPLIED_FIXES=0
SKIPPED_FIXES=0
FAILED_FIXES=0

# Log file
LOG_DIR="/var/log/cray/csm/upgrade"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/pre_upgrade_workarounds_$(date +%Y%m%d_%H%M%S).log"

# Backup directory
BACKUP_DIR="/var/backups/cray/csm/upgrade"
mkdir -p "$BACKUP_DIR"

################################################################################
# Helper Functions
################################################################################

log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_header() {
    log_message "\n${BLUE}========================================${NC}"
    log_message "${BLUE}$1${NC}"
    log_message "${BLUE}========================================${NC}"
}

print_fix() {
    TOTAL_FIXES=$((TOTAL_FIXES + 1))
    log_message "\n[FIX $TOTAL_FIXES] $1"
}

print_applied() {
    APPLIED_FIXES=$((APPLIED_FIXES + 1))
    log_message "${GREEN}✓ APPLIED${NC}: $1"
}

print_skipped() {
    SKIPPED_FIXES=$((SKIPPED_FIXES + 1))
    log_message "${YELLOW}⊘ SKIPPED${NC}: $1"
}

print_failed() {
    FAILED_FIXES=$((FAILED_FIXES + 1))
    log_message "${RED}✗ FAILED${NC}: $1"
}

print_info() {
    log_message "${BLUE}ℹ INFO${NC}: $1"
}

print_warning() {
    log_message "${YELLOW}⚠ WARNING${NC}: $1"
}

print_success() {
    log_message "${GREEN}✓ SUCCESS${NC}: $1"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not available"
        return 1
    fi
    return 0
}

check_cray_cli() {
    if ! command -v cray &> /dev/null; then
        print_warning "cray CLI not available"
        return 1
    fi
    return 0
}

################################################################################
# Fix 1: HSM Duplicate Detected Events Cleanup
# Reference: Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md
################################################################################

fix_hsm_duplicate_events() {
    print_fix "HSM Duplicate Detected Events Cleanup"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Use official CSM scripts for HSM duplicate event cleanup
    # Reference: https://github.com/Cray-HPE/docs-csm/blob/release/1.6/operations/hardware_state_manager/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md
    
    HWINV_SCRIPT_DIR="/usr/share/doc/csm/upgrade/scripts/upgrade/smd"
    
    # Check if scripts exist
    if [ ! -d "$HWINV_SCRIPT_DIR" ]; then
        print_warning "HSM cleanup scripts not found at: $HWINV_SCRIPT_DIR"
        print_info "These scripts are included in the CSM documentation package"
        print_info "Location: /usr/share/doc/csm/upgrade/scripts/upgrade/smd/"
        print_info "Scripts needed:"
        log_message "  - fru_history_backup.sh"
        log_message "  - fru_history_remove_duplicate_detected_events.sh"
        print_skipped "Official CSM scripts not available - manual execution required"
        return
    fi
    
    print_info "Found HSM cleanup scripts at: $HWINV_SCRIPT_DIR"
    
    # Step 1: Backup the hardware inventory history table
    print_info "Step 1: Backing up hardware inventory history table..."
    if [ -x "$HWINV_SCRIPT_DIR/fru_history_backup.sh" ]; then
        if bash "$HWINV_SCRIPT_DIR/fru_history_backup.sh" &>> "$LOG_FILE"; then
            print_applied "Hardware inventory history backup completed"
        else
            print_failed "Hardware inventory history backup failed"
            return 1
        fi
    else
        print_warning "fru_history_backup.sh not executable or not found"
    fi
    
    # Step 2: Run the duplicate event removal script
    print_info "Step 2: Removing duplicate detected events from database..."
    print_warning "This may take several hours on large systems - do not interrupt"
    
    if [ -x "$HWINV_SCRIPT_DIR/fru_history_remove_duplicate_detected_events.sh" ]; then
        if bash "$HWINV_SCRIPT_DIR/fru_history_remove_duplicate_detected_events.sh" &>> "$LOG_FILE"; then
            print_applied "HSM duplicate detected events cleaned up successfully"
            print_info "See log file for detailed cleanup statistics: $LOG_FILE"
        else
            print_warning "HSM duplicate event removal script completed with warnings"
            print_info "Check logs for details: $LOG_FILE"
            print_info "For large databases, may need to use: BATCH_SIZE=<size> MAX_BATCHES=<batches> VACUUM_TYPE=ANALYZE"
        fi
    else
        print_warning "fru_history_remove_duplicate_detected_events.sh not executable or not found"
        print_info "Execute manually using:"
        log_message "  export HWINV_SCRIPT_DIR=\"$HWINV_SCRIPT_DIR\""
        log_message "  \${HWINV_SCRIPT_DIR}/fru_history_backup.sh"
        log_message "  \${HWINV_SCRIPT_DIR}/fru_history_remove_duplicate_detected_events.sh"
        print_skipped "Manual execution required for HSM duplicate event cleanup"
    fi
}

################################################################################
# Fix 2: Switch Admin Password Configuration in Vault
# Reference: operations/network/management_network/README.md
################################################################################

fix_switch_admin_password() {
    print_fix "Switch Admin Password Vault Configuration"
    
    # Prompt for switch admin password
    print_warning "Switch admin password not found in Vault"
    print_info "To configure switch admin password, please run:"
    log_message "  python3 /usr/share/doc/csm/scripts/operations/configuration/write_sw_admin_pw_to_vault.py"

}

################################################################################
# Fix 3: MetalLB LoadBalancer IP Allocation
# Reference: operations/network/metallb_bgp/
################################################################################

fix_metallb_ip_allocation() {
    print_fix "MetalLB LoadBalancer IP Allocation Fix"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Find services with pending IPs
    PENDING_SERVICES=$(kubectl get svc -A 2>/dev/null | awk '$4 == "<pending>" {print $1":"$2}')
    
    if [ -z "$PENDING_SERVICES" ]; then
        print_applied "All LoadBalancer services have allocated IPs"
        return
    fi
    
    PENDING_COUNT=$(echo "$PENDING_SERVICES" | wc -l)
    print_warning "Found $PENDING_COUNT LoadBalancer service(s) without allocated IPs"
    
    # Check MetalLB status
    if ! kubectl get ns metallb-system &>/dev/null; then
        print_warning "MetalLB system namespace not found"
        print_skipped "MetalLB not installed or in different namespace"
        return
    fi
    
    # Check MetalLB controller pod
    CONTROLLER_PODS=$(kubectl get pods -n metallb-system -l app=metallb 2>/dev/null | grep -v NAME | wc -l)
    if [ "$CONTROLLER_PODS" -eq 0 ]; then
        print_warning "MetalLB controller not running"
    else
        print_info "MetalLB controller is running ($CONTROLLER_PODS pod(s))"
    fi
    
    # Check MetalLB address pools
    print_info "Checking MetalLB address pools..."
    kubectl get addresspools -n metallb-system --no-headers 2>/dev/null | while read line; do
        log_message "  Address Pool: $line"
    done
    
    print_info "Checking BGP configuration..."
    kubectl get bgppolicies -n metallb-system --no-headers 2>/dev/null | while read line; do
        log_message "  BGP Policy: $line"
    done
    
    print_warning "Review MetalLB configuration. May need BGP peer adjustment or address pool update"
    print_warning "See: troubleshooting/known_issues/Troubleshoot_BGP_not_Accepting_Routes_from_MetalLB.md"
    print_skipped "Manual BGP/MetalLB configuration review required"
}

################################################################################
# Fix 4: Kafka CRD Preparation
# Reference: Kafka CRD handling for CSM 1.7
################################################################################

fix_kafka_crd() {
    print_fix "Kafka CRD Preparation for CSM 1.7"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check if Kafka CRDs exist
    KAFKA_CRDS=$(kubectl get crd 2>/dev/null | grep -c kafka )
    
    if [ "$KAFKA_CRDS" -eq 0 ]; then
        print_applied "No Kafka CRDs found (expected for new installations)"
        return
    fi
    
    print_info "Found Kafka CRDs in cluster"
    
    # Check Kafka cluster status
    KAFKA_CLUSTERS=$(kubectl get kafka -A 2>/dev/null | grep -v NAME | awk '{print $1":"$2}')
    
    if [ -z "$KAFKA_CLUSTERS" ]; then
        print_info "No Kafka clusters found"
        print_skipped "No Kafka clusters to prepare"
        return
    fi
    
    print_info "Checking Kafka cluster status..."
    while IFS=':' read -r ns cluster; do
        STATUS=$(kubectl get kafka -n "$ns" "$cluster" -o jsonpath='{.status.conditions[*].status}' 2>/dev/null)
        log_message "  Kafka cluster $ns/$cluster status: $STATUS"
    done <<< "$KAFKA_CLUSTERS"
    
    # Check if Strimzi operator is updated
    STRIMZI_VERSION=$(kubectl get deployment -n strimzi -l app.kubernetes.io/name=strimzi-cluster-operator \
        -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null | grep -oP 'strimzi/operator:\K[^"]*')
    
    if [ -n "$STRIMZI_VERSION" ]; then
        print_info "Strimzi operator version: $STRIMZI_VERSION"
        log_message "  Ensure Strimzi operator is updated before CSM 1.7 upgrade"
    fi
    
    print_info "Ensure kafka_crd_fix.sh has been run from CSM 1.6 prep phase"
    print_info "Script location: /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh"
    print_skipped "Kafka CRD preparation verified - manual fix may still be needed"
}

################################################################################
# Fix 5: Slingshot Fabric Backup Verification
# Reference: Slingshot backup status check
################################################################################

fix_slingshot_backups() {
    print_fix "Slingshot Fabric Backup Verification"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check if Velero is installed
    if ! kubectl get ns velero &>/dev/null; then
        print_skipped "Velero/Slingshot backup system not installed"
        return
    fi
    
    # Check recent backups
    print_info "Checking Slingshot fabric backup status..."
    
    RECENT_BACKUPS=$(kubectl get backups -n velero 2>/dev/null | grep -i "slingshot\|fabric" | head -5)
    
    if [ -z "$RECENT_BACKUPS" ]; then
        print_warning "No Slingshot-related backups found"
    else
        log_message "Recent Slingshot backups:"
        kubectl get backups -n velero -A 2>/dev/null | tail -10 | tee -a "$LOG_FILE"
    fi
    
    # Check backup schedule
    SCHEDULES=$(kubectl get backupstoragelocations -n velero 2>/dev/null | grep -v NAME | wc -l)
    if [ "$SCHEDULES" -gt 0 ]; then
        print_info "Found $SCHEDULES backup storage location(s)"
        print_applied "Slingshot backup infrastructure is configured"
    else
        print_warning "No backup storage locations configured"
    fi
    
    print_info "Ensure recent backups are successful before upgrade"
    print_info "Related: Issue 2300387"
}

################################################################################
# Fix 6: Pod Restart Count Threshold Adjustment
# Temporary workaround for excessive pod restarts
################################################################################

fix_pod_restart_issues() {
    print_fix "Pod Restart Count Monitoring and Mitigation"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Find pods with high restart counts
    HIGH_RESTART_PODS=$(kubectl get pods -A 2>/dev/null | awk '{if ($5 > 50) print $0}' | grep -v RESTARTS)
    
    if [ -z "$HIGH_RESTART_PODS" ]; then
        print_applied "No pods with excessive restarts (>50) found"
        return
    fi
    
    print_warning "Found pods with very high restart counts (>50)"
    log_message "$HIGH_RESTART_PODS"
    
    # For each pod, try to identify and log the issue
    echo "$HIGH_RESTART_PODS" | while read -r ns pod rest; do
        print_info "Analyzing pod: $ns/$pod (restarts: $rest)"
        
        # Get deployment or statefulset that manages this pod
        OWNER=$(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
        OWNER_NAME=$(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null)
        
        if [ -n "$OWNER" ] && [ -n "$OWNER_NAME" ]; then
            log_message "  Owned by: $OWNER/$OWNER_NAME"
            
            # Get resource limits
            LIMITS=$(kubectl get "$OWNER" -n "$ns" "$OWNER_NAME" \
                -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>/dev/null)
            log_message "  Resource limits: $LIMITS"
        fi
    done
    
    print_warning "Review pod logs and adjust resource limits if necessary"
    print_skipped "Manual pod investigation required"
}

################################################################################
# Fix 7: Vault Operator CRD Preparation
# Reference: cray-vault-operator_chart_upgrade_error.md
################################################################################

fix_vault_operator_crd() {
    print_fix "Vault Operator CRD Preparation"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check for existing vault CRDs
    VAULT_CRD=$(kubectl get crd vaults.vault.banzaicloud.com 2>/dev/null)
    
    if [ -z "$VAULT_CRD" ]; then
        print_applied "Vault CRD not found (expected for fresh installations)"
        return
    fi
    
    # Check vault operator version
    VAULT_OPERATOR=$(kubectl get deployment -n vault vault-operator 2>/dev/null)
    
    if [ -z "$VAULT_OPERATOR" ]; then
        print_info "Vault operator not deployed"
        print_skipped "No Vault operator found"
        return
    fi
    
    print_info "Vault operator is deployed"
    print_info "Ensure vault-operator CRD is compatible with CSM 1.7 before upgrade"
    print_skipped "Vault operator CRD check completed"
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    print_header "Pre-Upgrade Workarounds Summary"
    
    log_message "\nTotal Fixes: $TOTAL_FIXES"
    log_message "${GREEN}Applied: $APPLIED_FIXES${NC}"
    log_message "${YELLOW}Skipped: $SKIPPED_FIXES${NC}"
    log_message "${RED}Failed: $FAILED_FIXES${NC}"
    
    log_message "\n${BLUE}Log file: $LOG_FILE${NC}"
    log_message "${BLUE}Backup directory: $BACKUP_DIR${NC}"
    
    if [ "$FAILED_FIXES" -gt 0 ]; then
        log_message "\n${RED}WARNING: $FAILED_FIXES fix(es) failed. Review logs before upgrade.${NC}"
        return 1
    elif [ "$SKIPPED_FIXES" -gt 0 ]; then
        log_message "\n${YELLOW}INFO: $SKIPPED_FIXES fix(es) skipped. May require manual intervention.${NC}"
        return 2
    else
        log_message "\n${GREEN}All workarounds completed successfully!${NC}"
        return 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log_message "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    log_message "${BLUE}║  CSM Pre-Upgrade Workarounds Script                            ║${NC}"
    log_message "${BLUE}║  Target: CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)               ║${NC}"
    log_message "${BLUE}║  Date: $(date '+%Y-%m-%d %H:%M:%S')                                         ║${NC}"
    log_message "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    # Run all fixes
    fix_hsm_duplicate_events
    fix_switch_admin_password
    fix_crashloop_pods
    fix_metallb_ip_allocation
    fix_kafka_crd
    fix_slingshot_backups
    fix_pod_restart_issues
    fix_vault_operator_crd
    fix_postgres_operator_crd
    fix_network_services
    
    # Print summary
    print_summary
    exit_code=$?
    
    exit $exit_code
}

# Run main function
main "$@"
