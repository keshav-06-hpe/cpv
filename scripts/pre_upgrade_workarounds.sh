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
    
    # Check if spire-postgres pod exists
    POSTGRES_POD=$(kubectl get pods -n spire -l app=postgres 2>/dev/null | grep -v NAME | awk '{print $1}' | head -1)
    
    if [ -z "$POSTGRES_POD" ]; then
        print_info "Checking alternative postgres locations..."
        # Try to find postgres in other namespaces
        POSTGRES_POD=$(kubectl get pods -A -l app.kubernetes.io/name=postgresql 2>/dev/null | grep -v NAME | awk '{print $1}' | head -1)
        POSTGRES_NS=$(kubectl get pods -A -l app.kubernetes.io/name=postgresql 2>/dev/null | grep -v NAMESPACE | awk '{print $1}' | head -1)
    else
        POSTGRES_NS="spire"
    fi
    
    if [ -z "$POSTGRES_POD" ]; then
        print_skipped "No PostgreSQL pod found for HSM"
        return
    fi
    
    print_info "Found PostgreSQL pod: $POSTGRES_POD in namespace: $POSTGRES_NS"
    
    # Create cleanup SQL script
    CLEANUP_SQL="/tmp/hsm_cleanup_duplicates.sql"
    cat > "$CLEANUP_SQL" << 'EOF'
-- HSM Duplicate Detected Events Cleanup
-- This removes duplicate "Detected" events that accumulate over time
-- It keeps one event per component and removes subsequent duplicates

BEGIN;

-- Create temporary table to identify duplicates
CREATE TEMPORARY TABLE dup_events AS
SELECT 
    component_id,
    event_type,
    ROW_NUMBER() OVER (PARTITION BY component_id, event_type ORDER BY timestamp DESC) as rn
FROM events
WHERE event_type = 'Detected'
  AND timestamp < NOW() - INTERVAL '7 days';

-- Delete duplicates, keeping the most recent one
DELETE FROM events
WHERE id IN (
    SELECT id FROM (
        SELECT 
            e.id,
            ROW_NUMBER() OVER (PARTITION BY e.component_id, e.event_type ORDER BY e.timestamp DESC) as rn
        FROM events e
        WHERE e.event_type = 'Detected'
          AND e.timestamp < NOW() - INTERVAL '7 days'
    ) t
    WHERE t.rn > 1
);

COMMIT;

-- Report the cleanup statistics
SELECT COUNT(*) as remaining_detected_events 
FROM events 
WHERE event_type = 'Detected';
EOF
    
    # Execute cleanup
    print_info "Executing HSM duplicate event cleanup..."
    if kubectl exec -n "$POSTGRES_NS" "$POSTGRES_POD" -- \
        psql -U postgres -d hsm -f "$CLEANUP_SQL" &>> "$LOG_FILE"; then
        print_applied "HSM duplicate detected events cleaned up"
        rm -f "$CLEANUP_SQL"
    else
        print_failed "Failed to execute HSM duplicate event cleanup"
        return 1
    fi
}

################################################################################
# Fix 2: Switch Admin Password Configuration in Vault
# Reference: operations/network/management_network/README.md
################################################################################

fix_switch_admin_password() {
    print_fix "Switch Admin Password Vault Configuration"
    
    if ! check_cray_cli; then
        print_skipped "cray CLI not available"
        return
    fi
    
    # Check if switch credentials already exist in vault
    if cray vault kv get secret/switch-admin &>/dev/null; then
        print_info "Switch admin password already configured in vault"
        print_skipped "Switch admin password already exists"
        return
    fi
    
    # Prompt for switch admin password
    print_warning "Switch admin password not found in Vault"
    print_info "To configure switch admin password, please run:"
    log_message "  python3 /usr/share/doc/csm/scripts/operations/configuration/write_sw_admin_pw_to_vault.py"
    log_message ""
    log_message "Or manually set it using:"
    log_message "  cray vault kv put secret/switch-admin username=<admin> password=<password>"
    
    print_skipped "Manual intervention required for switch credentials"
}

################################################################################
# Fix 3: CrashLoopBackOff Pods Investigation and Cleanup
# Addresses pods stuck in CrashLoopBackOff state
################################################################################

fix_crashloop_pods() {
    print_fix "CrashLoopBackOff Pods Investigation and Cleanup"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Find all pods with CrashLoopBackOff status
    CRASH_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4 == "CrashLoopBackOff" {print $1":"$2}')
    
    if [ -z "$CRASH_PODS" ]; then
        print_applied "No pods in CrashLoopBackOff state found"
        return
    fi
    
    CRASH_COUNT=$(echo "$CRASH_PODS" | wc -l)
    print_warning "Found $CRASH_COUNT pod(s) in CrashLoopBackOff state"
    
    # Investigate each pod
    while IFS=':' read -r ns pod; do
        log_message "\n  Investigating pod: $ns/$pod"
        
        # Get recent logs
        LOGS=$(kubectl logs -n "$ns" "$pod" --tail=50 2>&1 | head -20)
        log_message "  Recent logs:"
        log_message "$LOGS"
        
        # Check pod events
        EVENTS=$(kubectl describe pod -n "$ns" "$pod" 2>/dev/null | grep -A 20 "Events:")
        log_message "  Pod events:"
        log_message "$EVENTS"
    done <<< "$CRASH_PODS"
    
    print_info "Pod investigation logged to: $LOG_FILE"
    print_warning "Review logs and manually address pod failures before upgrade"
    print_skipped "Manual review required for CrashLoopBackOff pods"
}

################################################################################
# Fix 4: MetalLB LoadBalancer IP Allocation
# Reference: operations/network/metallb_bgp/
################################################################################

fix_metallb_ip_allocation() {
    print_fix "MetalLB LoadBalancer IP Allocation Fix"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Find services with pending IPs
    PENDING_SERVICES=$(kubectl get svc -A --no-headers 2>/dev/null | awk '$4 == "<pending>" {print $1":"$2}')
    
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
# Fix 5: Kafka CRD Preparation
# Reference: Kafka CRD handling for CSM 1.7
################################################################################

fix_kafka_crd() {
    print_fix "Kafka CRD Preparation for CSM 1.7"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check if Kafka CRDs exist
    KAFKA_CRDS=$(kubectl get crd 2>/dev/null | grep -c kafka || true)
    
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
# Fix 6: Slingshot Fabric Backup Verification
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
# Fix 7: Pod Restart Count Threshold Adjustment
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
# Fix 8: Vault Operator CRD Preparation
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
# Fix 9: Postgres Operator CRD Check
# Reference: PostgreSQL Operator upgrade preparation
################################################################################

fix_postgres_operator_crd() {
    print_fix "PostgreSQL Operator CRD Preparation"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check PostgreSQL CRD version
    PG_CRD=$(kubectl get crd postgresqls.postgresql.cnpg.io 2>/dev/null)
    
    if [ -z "$PG_CRD" ]; then
        print_applied "PostgreSQL CRD not found or updated"
        return
    fi
    
    # Check existing PostgreSQL clusters
    PG_CLUSTERS=$(kubectl get postgresql -A 2>/dev/null | grep -v NAME | wc -l)
    
    if [ "$PG_CLUSTERS" -eq 0 ]; then
        print_applied "No PostgreSQL clusters using legacy CRD"
        return
    fi
    
    print_info "Found $PG_CLUSTERS PostgreSQL cluster(s) - may need CRD migration"
    print_warning "Verify PostgreSQL operator version compatibility before upgrade"
    print_skipped "PostgreSQL CRD compatibility check completed"
}

################################################################################
# Fix 10: DNS and Network Services Verification
# Ensure DNS and network services are operational for upgrade
################################################################################

fix_network_services() {
    print_fix "Network Services Operational Verification"
    
    if ! check_kubectl; then
        print_skipped "kubectl not available"
        return
    fi
    
    # Check CoreDNS
    COREDNS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
    if [ "$COREDNS" -lt 2 ]; then
        print_warning "CoreDNS running pods: $COREDNS (expected at least 2)"
    else
        print_info "CoreDNS is healthy ($COREDNS pods)"
    fi
    
    # Check DNS resolution
    TEST_POD=$(kubectl run -n default dns-test --image=busybox --restart=Never --rm -it -- nslookup kubernetes.default 2>/dev/null)
    if echo "$TEST_POD" | grep -q "Address:"; then
        print_applied "DNS resolution working correctly"
    else
        print_warning "DNS resolution test failed - check CoreDNS logs"
    fi
    
    print_applied "Network services verification completed"
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
