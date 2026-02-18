#!/bin/bash
################################################################################
# CSM Pre-Install / Pre-Upgrade Check Script
# Version: 1.1
# Purpose: Validate system readiness for CSM 25.3.2 (1.6.2) to 25.9.0 (1.7.0)
# 
# This script performs read-only checks for known issues that could impact
# pre-installation or upgrade readiness. It does NOT make changes.
################################################################################

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Log file
LOG_DIR="/etc/cray/upgrade/csm/pre-checks"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/pre_upgrade_checks_$(date +%Y%m%d_%H%M%S).log"

# Mode (pre-install or pre-upgrade)
SCRIPT_MODE="pre-upgrade"

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

print_check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    log_message "\n[CHECK $TOTAL_CHECKS] $1"
}

print_pass() {
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    log_message "${GREEN}✓ PASS${NC}: $1"
}

print_fail() {
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    log_message "${RED}✗ FAIL${NC}: $1"
}

print_warning() {
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    log_message "${YELLOW}⚠ WARNING${NC}: $1"
}

print_info() {
    log_message "${BLUE}ℹ INFO${NC}: $1"
}

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [-m pre-install|pre-upgrade] [-h]

Options:
  -m    Mode for checks (default: pre-upgrade)
  -h    Show this help message

Note: This script is read-only and performs pre-install or pre-upgrade checks.
EOF
}

set_mode() {
    case "$1" in
        pre-install|pre-upgrade) SCRIPT_MODE="$1" ;;
        *)
            print_warning "Invalid mode '$1'. Using default: pre-upgrade"
            SCRIPT_MODE="pre-upgrade"
            ;;
    esac
}

check_command() {
    local cmd="$1"
    local msg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        print_warning "$msg"
        return 1
    fi
    return 0
}

################################################################################
# CSM Checks
################################################################################

check_csm_issues() {
    print_header "CSM Core Issues"
    
    # Check 1: Nexus Space
    print_check "Checking Nexus storage space"
    if command -v kubectl &> /dev/null; then
        NEXUS_PVC=$(kubectl get pvc -n nexus 2>/dev/null | grep nexus | awk '{print $1}')
        if [ -n "$NEXUS_PVC" ]; then
            USAGE=$(kubectl exec -n nexus deployment/nexus -c nexus -- df -h /nexus-data 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
            if [ "$USAGE" -gt 80 ]; then
                print_fail "Nexus storage usage is ${USAGE}% (>80%). Consider cleanup before upgrade."
                log_message "       See: https://cray-hpe.github.io/docs-csm/en-17/operations/package_repository_management/nexus_space_cleanup/"
                log_message "       Related: CASMTRIAGE-8826"
            else
                print_pass "Nexus storage usage is ${USAGE}% (acceptable)"
            fi
        else
            print_warning "Could not find Nexus PVC"
        fi
    else
        print_warning "kubectl not available, skipping Nexus space check"
    fi
    
    # Check 3: Kafka CRD Issue
    print_check "Checking for Kafka CRD issues"
    if command -v kubectl &> /dev/null; then
        KAFKA_CRDS=$(kubectl get crd 2>/dev/null | grep -c kafka)
        if [ "$KAFKA_CRDS" -gt 0 ]; then
            print_info "Found Kafka CRDs. Ensure kafka_crd_fix.sh has been run from CSM 1.6 prep"
            log_message "       Script location: /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh"
        else
            print_warning "No Kafka CRDs found (unexpected)"
        fi
    fi
}

################################################################################
# Kubernetes Health Validation
# Reference: operations/validate_csm_health/
################################################################################

check_kubernetes_health() {
    print_header "Kubernetes Cluster Health"
    
    # Check 1: Node status
    print_check "Checking Kubernetes node status"
    if command -v kubectl &> /dev/null; then
        NOT_READY=$(kubectl get nodes 2>/dev/null | grep -v Ready | grep -v NAME | wc -l)
        if [ "$NOT_READY" -gt 0 ]; then
            print_fail "$NOT_READY nodes not in Ready state"
            kubectl get nodes | grep -v Ready | grep -v NAME | tee -a "$LOG_FILE"
            log_message "       Reference: operations/validate_csm_health/"
        else
            print_pass "All Kubernetes nodes Ready"
        fi
    else
        print_warning "kubectl not available"
    fi
    
    # Check 2: Critical system pods
    print_check "Checking critical system pods"
    if command -v kubectl &> /dev/null; then
        CRITICAL_NAMESPACES="kube-system services nexus vault"
        for ns in $CRITICAL_NAMESPACES; do
            FAILED_PODS=$(kubectl get pods -n $ns 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
            if [ "$FAILED_PODS" -gt 0 ]; then
                print_warning "Found $FAILED_PODS non-running pods in namespace $ns"
                kubectl get pods -n $ns | grep -v Running | grep -v Completed | grep -v NAME | tee -a "$LOG_FILE"
            fi
        done
        print_pass "Critical namespace pod check completed"
    fi

    # Check 3: Pods with high restart counts
    print_check "Checking for pods with high restart counts"
    if command -v kubectl &> /dev/null; then
        HIGH_RESTARTS=$(kubectl get pods -A 2>/dev/null | awk '{if ($5 > 10) print $0}' | grep -v RESTARTS | wc -l)
        if [ "$HIGH_RESTARTS" -gt 0 ]; then
            print_warning "Found $HIGH_RESTARTS pods with >10 restarts"
            kubectl get pods -A | awk '{if ($5 > 10) print $0}' | grep -v RESTARTS | head -10 | tee -a "$LOG_FILE"
            log_message "       Review logs for these pods before upgrade"
        else
            print_pass "No pods with excessive restarts"
        fi
    fi

    # Check 4: Persistent Volume Claims
    print_check "Checking PVC status"
    if command -v kubectl &> /dev/null; then
        PENDING_PVC=$(kubectl get pvc -A 2>/dev/null | grep -v Bound | grep -v STATUS | wc -l)
        if [ "$PENDING_PVC" -gt 0 ]; then
            print_fail "Found $PENDING_PVC PVCs not in Bound state"
            kubectl get pvc -A | grep -v Bound | grep -v STATUS | tee -a "$LOG_FILE"
        else
            print_pass "All PVCs in Bound state"
        fi
    fi
}

################################################################################
# Ceph Storage Health
# Reference: operations/utility_storage/
################################################################################

check_ceph_health() {
    print_header "Ceph Storage Health"

    # Check 1: Ceph cluster status
    print_check "Checking Ceph cluster health"
    if command -v ceph &> /dev/null; then
        CEPH_STATUS=$(ceph health 2>/dev/null | awk '{print $1}')
        case "$CEPH_STATUS" in
            "HEALTH_OK")
                print_pass "Ceph cluster health: OK"
                ;;
            "HEALTH_WARN")
                print_warning "Ceph cluster health: WARNING"
                ceph health detail | tee -a "$LOG_FILE"
                log_message "       Reference: operations/utility_storage/"
                ;;
            "HEALTH_ERR"|*)
                print_fail "Ceph cluster health: ERROR or UNKNOWN ($CEPH_STATUS)"
                ceph health detail | tee -a "$LOG_FILE"
                log_message "       Resolve Ceph issues before upgrade"
                ;;
        esac
    else
        print_warning "ceph command not available, skipping Ceph health check"
    fi

    # Check 2: OSD status
    print_check "Checking Ceph OSD status"
    if command -v ceph &> /dev/null; then
        OSD_STAT=$(ceph osd stat 2>/dev/null)
        DOWN_OSDS=$(echo "$OSD_STAT" | grep -oP '\d+ down' | awk '{print $1}')
        if [ -n "$DOWN_OSDS" ] && [ "$DOWN_OSDS" -gt 0 ]; then
            print_fail "$DOWN_OSDS OSDs are down"
            ceph osd tree | tee -a "$LOG_FILE"
        else
            print_pass "All OSDs are up"
        fi
    fi

    # Check 3: Ceph usage
    print_check "Checking Ceph storage usage"
    if command -v ceph &> /dev/null; then
        CEPH_USAGE=$(ceph df 2>/dev/null | grep TOTAL | awk '{print $5}' | sed 's/%//')
        if [ -n "$CEPH_USAGE" ]; then
            if [ "$CEPH_USAGE" -gt 80 ]; then
                print_fail "Ceph storage usage at ${CEPH_USAGE}% (>80%)"
                log_message "       Free up space before upgrade"
            elif [ "$CEPH_USAGE" -gt 70 ]; then
                print_warning "Ceph storage usage at ${CEPH_USAGE}% (approaching threshold)"
            else
                print_pass "Ceph storage usage at ${CEPH_USAGE}% (acceptable)"
            fi
        fi
    fi
}

################################################################################
# Spire Health Check
# Reference: operations/spire/ and troubleshooting/known_issues/spire_*.md
################################################################################

check_spire_health() {
    print_header "Spire Service Health"

    # Check 1: Spire pods
    print_check "Checking Spire pod status"
    if command -v kubectl &> /dev/null; then
        SPIRE_PODS=$(kubectl get pods -n spire 2>/dev/null | grep spire-server | grep -v Running | wc -l)
        if [ "$SPIRE_PODS" -gt 0 ]; then
            print_fail "Spire server pods not running properly"
            kubectl get pods -n spire | grep spire-server | tee -a "$LOG_FILE"
            log_message "       Reference: operations/spire/"
        else
            print_pass "Spire server pods healthy"
        fi
    fi

    # Check 2: Spire agents
    print_check "Checking Spire agent status"
    if command -v kubectl &> /dev/null; then
        SPIRE_AGENTS=$(kubectl get pods -n spire 2>/dev/null | grep spire-agent | grep -v Running | wc -l)
        if [ "$SPIRE_AGENTS" -gt 0 ]; then
            print_warning "$SPIRE_AGENTS Spire agent pods not running"
            kubectl get pods -n spire | grep spire-agent | grep -v Running | tee -a "$LOG_FILE"
        else
            print_pass "All Spire agents running"
        fi
    fi

    # Check 3: Common Spire issues
    print_check "Checking for known Spire issues"
    if command -v kubectl &> /dev/null; then
        INITIALIZING=$(kubectl get pods -n spire 2>/dev/null | grep PodInitializing | wc -l)
        if [ "$INITIALIZING" -gt 0 ]; then
            print_warning "$INITIALIZING Spire pods stuck in PodInitializing state"
            log_message "       Reference: troubleshooting/known_issues/spire_pod_initializing.md"
        else
            print_pass "No Spire pods stuck in PodInitializing"
        fi

        # Check for postgres issues
        POSTGRES_SPIRE=$(kubectl get pods -n spire 2>/dev/null | grep postgres | grep -v Running | wc -l)
        if [ "$POSTGRES_SPIRE" -gt 0 ]; then
            print_fail "Spire PostgreSQL pods not running"
            log_message "       Reference: troubleshooting/known_issues/spire_postgres_*.md"
        else
            print_pass "Spire PostgreSQL pods healthy"
        fi
    fi
}

################################################################################
# PostgreSQL Database Health
# Reference: operations/kubernetes/Troubleshoot_Postgres_Database.md
################################################################################

check_postgres_health() {
    print_header "PostgreSQL Database Health"

    # Check 1: PostgreSQL clusters
    print_check "Checking PostgreSQL cluster status"
    if command -v kubectl &> /dev/null; then
        PG_CLUSTERS=$(kubectl get postgresql -A 2>/dev/null | grep -v NAME | awk '{print $1":"$2}')

        if [ -z "$PG_CLUSTERS" ]; then
            print_info "No PostgreSQL clusters found (or CRD not installed)"
        else
            for cluster in $PG_CLUSTERS; do
                ns=$(echo $cluster | cut -d: -f1)
                name=$(echo $cluster | cut -d: -f2)

                RUNNING=$(kubectl get pods -n $ns -l application=spilo,cluster-name=$name 2>/dev/null | grep Running | wc -l)
                TOTAL=$(kubectl get postgresql -n $ns $name -o jsonpath='{.spec.numberOfInstances}' 2>/dev/null)

                if [ "$RUNNING" != "$TOTAL" ] && [ -n "$TOTAL" ]; then
                    print_warning "PostgreSQL $ns/$name: $RUNNING/$TOTAL instances running"
                else
                    print_pass "PostgreSQL $ns/$name: All instances running"
                fi
            done
        fi
    fi

    # Check 2: PostgreSQL pod status
    print_check "Checking for PostgreSQL pod issues"
    if command -v kubectl &> /dev/null; then
        POSTGRES_ERRORS=$(kubectl get pods -A 2>/dev/null | grep postgres | grep -v Running | grep -v Completed | wc -l)
        if [ "$POSTGRES_ERRORS" -gt 0 ]; then
            print_fail "Found $POSTGRES_ERRORS PostgreSQL pods not running"
            kubectl get pods -A | grep postgres | grep -v Running | grep -v Completed | tee -a "$LOG_FILE"
            log_message "       Reference: operations/kubernetes/Troubleshoot_Postgres_Database.md"
        else
            print_pass "All PostgreSQL pods healthy"
        fi
    fi

    # Check 3: Patroni cluster health
    print_check "Checking Patroni cluster health"
    if command -v kubectl &> /dev/null; then
        # Format: "cluster-name:namespace"
        POSTGRES_CLUSTERS=("keycloak-postgres:services" "gitea-vcs-postgres:services" "cray-spire-postgres:spire")
        PATRONI_ISSUES=0

        for CLUSTER_INFO in "${POSTGRES_CLUSTERS[@]}"; do
            POSTGRESQL=$(echo $CLUSTER_INFO | cut -d: -f1)
            NAMESPACE=$(echo $CLUSTER_INFO | cut -d: -f2)

            # Check if the postgres pod exists
            if kubectl get pod "${POSTGRESQL}-1" -n ${NAMESPACE} &> /dev/null; then
                PATRONI_OUTPUT=$(kubectl exec "${POSTGRESQL}-1" -c postgres -n ${NAMESPACE} -- patronictl list 2>/dev/null)

                if [ -n "$PATRONI_OUTPUT" ]; then
                    # Check for unhealthy states in patronictl output
                    if echo "$PATRONI_OUTPUT" | grep -iq "failed\|stopped\|unknown"; then
                        print_warning "Patroni cluster ${POSTGRESQL} (${NAMESPACE}) has unhealthy members"
                        echo "$PATRONI_OUTPUT" | tee -a "$LOG_FILE"
                        PATRONI_ISSUES=$((PATRONI_ISSUES + 1))
                    else
                        print_pass "Patroni cluster ${POSTGRESQL} (${NAMESPACE}) healthy"
                    fi
                else
                    print_warning "Could not retrieve Patroni status for ${POSTGRESQL} (${NAMESPACE})"
                    PATRONI_ISSUES=$((PATRONI_ISSUES + 1))
                fi
            fi
        done

        if [ "$PATRONI_ISSUES" -eq 0 ]; then
            print_pass "All Patroni clusters healthy"
        else
            log_message "       Reference: troubleshooting/known_issues/postgres_*.md"
        fi
    fi
}

################################################################################
# Network Services Validation
# Reference: operations/network/
################################################################################

check_network_services() {
    print_header "Network Services Health"

    # Check 1: DNS services
    print_check "Checking DNS services"
    if command -v kubectl &> /dev/null; then
        DNS_PODS=$(kubectl get pods -n services 2>/dev/null | grep cray-dns-unbound | grep Running | wc -l)
        if [ "$DNS_PODS" -eq 0 ]; then
            print_fail "DNS unbound pods not running"
            kubectl get pods -n services | grep cray-dns-unbound | tee -a "$LOG_FILE"
        else
            print_pass "DNS services running ($DNS_PODS pods)"
        fi
    fi

    # Check 2: DHCP services
    print_check "Checking DHCP services"
    if command -v kubectl &> /dev/null; then
        DHCP_PODS=$(kubectl get pods -n services 2>/dev/null | grep cray-dhcp-kea | grep Running | wc -l)
        if [ "$DHCP_PODS" -eq 0 ]; then
            print_fail "DHCP kea pods not running"
            kubectl get pods -n services | grep cray-dhcp-kea | tee -a "$LOG_FILE"
        else
            print_pass "DHCP services running ($DHCP_PODS pods)"
        fi
    fi

    # Check 3: MetalLB IP allocation
    print_check "Checking MetalLB IP allocation"
    if command -v kubectl &> /dev/null; then
        UNALLOCATED=$(kubectl get svc -A 2>/dev/null | grep LoadBalancer | grep '<pending>' | wc -l)
        if [ "$UNALLOCATED" -gt 0 ]; then
            print_warning "$UNALLOCATED LoadBalancer services without allocated IPs"
            kubectl get svc -A | grep LoadBalancer | grep '<pending>' | tee -a "$LOG_FILE"
            log_message "       Reference: operations/network/metallb_bgp/"
        else
            print_pass "All LoadBalancer services have allocated IPs"
        fi
    fi

    # Check 4: CoreDNS
    print_check "Checking CoreDNS pods"
    if command -v kubectl &> /dev/null; then
        COREDNS=$(kubectl get pods -n kube-system 2>/dev/null | grep coredns | grep Running | wc -l)
        if [ "$COREDNS" -lt 2 ]; then
            print_warning "CoreDNS running pods: $COREDNS (expected at least 2)"
        else
            print_pass "CoreDNS healthy ($COREDNS pods)"
        fi
    fi
}

################################################################################
# CSM Core Services Health
# Reference: operations/validate_csm_health/
################################################################################

check_csm_services_health() {
    print_header "CSM Core Services Health"

    # Check 1: HMS services
    print_check "Checking HMS services"
    if command -v kubectl &> /dev/null; then
        HMS_SERVICES="cray-hms-discovery cray-smd cray-sls"
        HMS_OK=true
        for svc in $HMS_SERVICES; do
            REPLICAS=$(kubectl get deployment -n services $svc -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
            DESIRED=$(kubectl get deployment -n services $svc -o jsonpath='{.spec.replicas}' 2>/dev/null)
            if [ "$REPLICAS" != "$DESIRED" ] && [ -n "$DESIRED" ]; then
                print_warning "$svc: $REPLICAS/$DESIRED replicas available"
                HMS_OK=false
            fi
        done
        if [ "$HMS_OK" = true ]; then
            print_pass "All HMS services have desired replicas"
        fi
    fi

    # Check 2: BSS (Boot Script Service)
    print_check "Checking BSS (Boot Script Service)"
    if command -v kubectl &> /dev/null; then
        BSS_STATUS=$(kubectl get pods -n services 2>/dev/null | grep cray-bss | grep Running | wc -l)
        if [ "$BSS_STATUS" -eq 0 ]; then
            print_fail "BSS pods not running"
            kubectl get pods -n services | grep cray-bss | tee -a "$LOG_FILE"
        else
            print_pass "BSS is running ($BSS_STATUS pods)"
        fi
    fi

    # Check 3: API Gateway
    print_check "Checking API Gateway"
    if command -v kubectl &> /dev/null; then
        GATEWAY=$(kubectl get pods -n istio-system 2>/dev/null | grep istio-ingressgateway | grep Running | wc -l)
        if [ "$GATEWAY" -eq 0 ]; then
            print_fail "API Gateway not running"
        else
            print_pass "API Gateway running ($GATEWAY pods)"
        fi
    fi
}

################################################################################
# HMS Services Validation (Enhanced)
# Reference: hpe-csm-scripts/scripts/hms_verification/
################################################################################

check_hms_services() {
    print_header "HMS Services Validation"

    # Critical HMS services from hpe-csm-scripts
    HMS_SERVICES=("bss:cray-bss" "capmc:cray-capmc" "fas:cray-fas" \
                  "hbtd:cray-hbtd" "hmnfd:cray-hmnfd" "hsm:cray-smd" \
                  "pcs:cray-power-control" "scsd:cray-scsd" "sls:cray-sls")
    
    FAILED_SERVICES=""
    WARNING_SERVICES=""

    for svc_pair in "${HMS_SERVICES[@]}"; do
        SVC_NAME=$(echo $svc_pair | cut -d: -f1)
        DEPLOYMENT=$(echo $svc_pair | cut -d: -f2)

        print_check "Checking HMS service: $SVC_NAME ($DEPLOYMENT)"

        if command -v kubectl &> /dev/null; then
            # Check if deployment exists
            if kubectl get deployment -n services $DEPLOYMENT &> /dev/null; then
                REPLICAS=$(kubectl get deployment -n services $DEPLOYMENT -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
                DESIRED=$(kubectl get deployment -n services $DEPLOYMENT -o jsonpath='{.spec.replicas}' 2>/dev/null)

                if [ "$REPLICAS" != "$DESIRED" ] || [ -z "$REPLICAS" ]; then
                    print_warning "$SVC_NAME: $REPLICAS/$DESIRED replicas available"
                    WARNING_SERVICES="$WARNING_SERVICES $SVC_NAME"
                else
                    print_pass "$SVC_NAME: All replicas running ($REPLICAS/$DESIRED)"
                fi

                # Check pod status
                FAILED_PODS=$(kubectl get pods -n services -l app.kubernetes.io/name=$DEPLOYMENT 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
                if [ "$FAILED_PODS" -gt 0 ]; then
                    print_warning "$SVC_NAME has $FAILED_PODS non-running pods"
                    WARNING_SERVICES="$WARNING_SERVICES $SVC_NAME"
                fi
            else
                print_info "$SVC_NAME deployment not found (may not be installed)"
            fi
        fi
    done

    # Summary of HMS service checks
    if [ -n "$FAILED_SERVICES" ]; then
        print_fail "Failed HMS services:$FAILED_SERVICES"
        log_message "       Reference: scripts/hms_verification/run_hms_ct_tests.sh"
    elif [ -n "$WARNING_SERVICES" ]; then
        print_warning "HMS services with warnings:$WARNING_SERVICES"
        log_message "       Consider running: /opt/cray/csm/scripts/hms_verification/run_hms_ct_tests.sh"
    else
        print_pass "All HMS services healthy"
    fi
}

################################################################################
# Hardware Health Checks
# Reference: hpe-csm-scripts/scripts/hms_verification/run_hardware_checks.sh
################################################################################

check_hardware_health() {
    print_header "Hardware Health Validation"

    # Check 1: HSM hardware state
    print_check "Checking HSM component state"
    if command -v cray &> /dev/null; then
        # Check for components in bad states
        if check_command "jq" "jq not available, skipping detailed HSM state parsing"; then
            EMPTY_COMPS=$(cray hsm state components list --format json 2>/dev/null | jq -r '.Components[] | select(.State == "Empty") | .ID' | wc -l)
            if [ "$EMPTY_COMPS" -gt 0 ]; then
                print_warning "Found $EMPTY_COMPS components in Empty state"
                log_message "       Review with: cray hsm state components list --state Empty"
            else
                print_pass "No components in Empty state"
            fi

            OFF_COMPS=$(cray hsm state components list --format json 2>/dev/null | jq -r '.Components[] | select(.State == "Off") | .ID' | wc -l)
            if [ "$OFF_COMPS" -gt 0 ]; then
                print_info "Found $OFF_COMPS components in Off state (may be expected)"
            fi
        fi
    else
        print_warning "Cray CLI not available, cannot check HSM state"
        log_message "       Install cray CLI or run on management node"
    fi

    # Check 2: Redfish endpoint discovery
    print_check "Checking Redfish endpoint discovery status"
    if command -v kubectl &> /dev/null; then
        HMS_DISCOVERY=$(kubectl get pods -n services 2>/dev/null | grep hms-discovery | grep Completed | wc -l)
        if [ "$HMS_DISCOVERY" -eq 0 ]; then
            print_fail "HMS discovery service not running"
            log_message "       Hardware discovery may be impacted during upgrade"
        else
            print_pass "HMS discovery service job completed"
        fi
    fi

    # Check 3: CAPMC hardware checks availability
    print_check "Checking CAPMC service for hardware validation"
    if command -v kubectl &> /dev/null; then
        CAPMC_PODS=$(kubectl get pods -n services 2>/dev/null | grep cray-capmc | grep Running | wc -l)
        if [ "$CAPMC_PODS" -gt 0 ]; then
            print_pass "CAPMC service running ($CAPMC_PODS pods)"
            log_message "       Optional: Run /opt/cray/csm/scripts/hms_verification/run_hardware_checks.sh"
            log_message "       This validates CAPMC and HSM hardware checks"
        else
            CAPMC_DEPLOYED=$(kubectl get deployment -n services cray-capmc 2>/dev/null)
            if [ -n "$CAPMC_DEPLOYED" ]; then
                print_warning "CAPMC deployment exists but no running pods"
                kubectl get pods -n services | grep cray-capmc | tee -a "$LOG_FILE"
            else
                print_warning "CAPMC not found - hardware validation limited"
            fi
        fi
    fi

    # Check 4: BMC/Controller connectivity
    print_check "Checking BMC/Controller reachability"
    if command -v kubectl &> /dev/null; then
        HMNFD_PODS=$(kubectl get pods -n services 2>/dev/null | grep cray-hmnfd | grep Running | wc -l)
        if [ "$HMNFD_PODS" -eq 0 ]; then
            print_warning "HMNFD (Hardware Management Notification Fanout Daemon) not running"
            log_message "       May impact hardware state change notifications"
        else
            print_pass "HMNFD running for hardware notifications"
        fi
    fi
}

################################################################################
# CSM 1.7 Specific Pre-Checks
# Reference: troubleshooting/known_issues/ and introduction/csi_Tool_Changes.md
################################################################################

check_csm_17_specific() {
    print_header "CSM 1.7 Specific Pre-Checks"

    # Check 1: CNI migration readiness (Weave → Cilium)
    print_check "Checking current CNI (Weave → Cilium migration in 1.7)"
    if command -v kubectl &> /dev/null; then
        CURRENT_CNI=$(kubectl get pods -n kube-system 2>/dev/null | grep -c weave)
        if [ "$CURRENT_CNI" -gt 0 ]; then
            print_info "Currently running Weave CNI - will be migrated to Cilium during upgrade"
            log_message "       Reference: troubleshooting/known_issues/cilium_migration_*.md"
            log_message "       Ensure BSS global metadata has k8s_primary_cni set"
        else
            CILIUM=$(kubectl get pods -n kube-system 2>/dev/null | grep -c cilium)
            if [ "$CILIUM" -gt 0 ]; then
                print_pass "Already running Cilium CNI"
            else
                print_warning "Could not determine current CNI"
            fi
        fi
    fi

    # Check 2: BSS global metadata for Cilium
    print_check "Checking BSS global metadata for Cilium migration"
    if command -v cray &> /dev/null; then
        BSS_METADATA=$(cray bss bootparameters list --name Global 2>/dev/null)
        if echo "$BSS_METADATA" | grep -q "k8s-primary-cni"; then
            K8S_CNI_VALUE=$(echo "$BSS_METADATA" | grep "k8s-primary-cni" | sed 's/.*k8s-primary-cni[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
            if [ "$K8S_CNI_VALUE" = "cilium" ]; then
                print_pass "k8s-primary-cni correctly set to 'cilium' in BSS global metadata"
            else
                print_fail "k8s-primary-cni is set to '$K8S_CNI_VALUE' but must be 'cilium'"
                log_message "       Run: cray bss bootparameters update --name Global"
                log_message "       Required to prevent: Cilium Migration Failure"
            fi
        else
            print_fail "k8s-primary-cni NOT found in BSS global metadata"
            log_message "       Run: cray bss bootparameters list --name Global"
            log_message "       Required to prevent: Cilium Migration Failure"
        fi
    else
        print_warning "Cray CLI not available, cannot check BSS metadata"
    fi
    
    # Check 3: Service etcd clusters
    print_check "Checking HMS service etcd clusters"
    if command -v kubectl &> /dev/null; then
        HMS_ETCD_SERVICES=("cray-bss" "cray-fas" "cray-fox" "cray-hbtd" "cray-hmnfd" "cray-power-control")
        ETCD_ISSUES=0

        for SERVICE in "${HMS_ETCD_SERVICES[@]}"; do
            ETCD_COUNT=$(kubectl get pods -n services 2>/dev/null | grep "${SERVICE}-bitnami-etcd-" | grep -v snapshotter | grep Running | wc -l)
            if [ "$ETCD_COUNT" -lt 3 ]; then
                if [ "$ETCD_COUNT" -eq 0 ]; then
                    print_info "${SERVICE} etcd cluster not found (service may not be installed)"
                else
                    print_warning "${SERVICE} etcd cluster has only ${ETCD_COUNT}/3 pods running"
                    kubectl get pods -n services | grep "${SERVICE}-bitnami-etcd-" | grep -v snapshotter | tee -a "$LOG_FILE"
                    ETCD_ISSUES=$((ETCD_ISSUES + 1))
                fi
            fi
        done

        if [ "$ETCD_ISSUES" -eq 0 ]; then
            print_pass "All HMS service etcd clusters healthy"
        else
            log_message "       Reference: operations/validate_csm_health/"
        fi
    fi

    # Check 4: Certificate validity
    print_check "Checking Kubernetes certificate expiration"
    if [ -f "/etc/kubernetes/pki/apiserver.crt" ]; then
        if check_command "openssl" "openssl not available, cannot check certificate expiration"; then
            CERT_EXPIRY=$(openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate 2>/dev/null | cut -d= -f2)
            if date -d "$CERT_EXPIRY" +%s &> /dev/null; then
                CERT_DAYS=$(( ( $(date -d "$CERT_EXPIRY" +%s) - $(date +%s) ) / 86400 ))
                if [ "$CERT_DAYS" -lt 30 ]; then
                    print_fail "Kubernetes certificates expire in $CERT_DAYS days (renew before upgrade)"
                elif [ "$CERT_DAYS" -lt 90 ]; then
                    print_warning "Kubernetes certificates expire in $CERT_DAYS days"
                else
                    print_pass "Kubernetes certificates valid for $CERT_DAYS days"
                fi
            else
                print_warning "Unable to parse certificate expiration date with 'date -d'"
            fi
        fi
    else
        print_info "Cannot check certificate expiration (not on master node?)"
    fi

    # Check 5: Vault token cleanup
    print_check "Checking Vault token configuration"
    if command -v kubectl &> /dev/null; then
        print_info "Ensure cray-vault-operator tokens are cleaned up"
        log_message "       Reference: troubleshooting/known_issues/cray_vault_operator_*.md"
        log_message "       Old tokens can cause upgrade issues"
    fi
}

################################################################################
# SHS (Slingshot Host Software) Checks
################################################################################

####### Commenting for future use #######

# check_shs_issues() {
#     print_header "Slingshot Host Software (SHS) Issues"

#     # Check 1: SS10 systems
#     print_check "Checking for SS10 hardware"
#     if command -v cray &> /dev/null; then
#         if check_command "jq" "jq not available, cannot parse HSM inventory for SS10"; then
#             SS10_COUNT=$(cray hsm inventory hardware list --format json 2>/dev/null | jq -r '.. | .Model? // empty' | grep -ci "SS10")
#             if [ -z "$SS10_COUNT" ]; then
#                 print_warning "Unable to determine SS10 presence from HSM inventory"
#             elif [ "$SS10_COUNT" -gt 0 ]; then
#                 print_warning "Detected SS10 hardware in inventory"
#                 log_message "       Continue using SHS-v12.0.x (SHS 13.0.0 not supported)"
#                 log_message "       Related: Issue - SS10 Not Supported"
#             else
#                 print_pass "No SS10 hardware detected in inventory"
#             fi
#         fi
#     else
#         print_info "Cray CLI not available; cannot check SS10 hardware"
#     fi
    
#     # Check 2: High rank count applications
#     print_check "Checking for affected Slurm/PALS versions (>252 ranks per node issue)"
#     AFFECTED=false
#     if command -v scontrol &> /dev/null; then
#         SLURM_VERSION=$(scontrol version 2>/dev/null | head -1)
#         if [[ "$SLURM_VERSION" == *"25.05"* ]]; then
#             AFFECTED=true
#             log_message "       Slurm 25.05 detected"
#         fi
#     fi
#     if command -v pals &> /dev/null; then
#         PALS_VERSION=$(pals --version 2>/dev/null | head -1)
#         if [[ "$PALS_VERSION" == *"1.7.1"* ]]; then
#             AFFECTED=true
#             log_message "       PALS 1.7.1 detected"
#         fi
#     fi
#     if [ "$AFFECTED" = true ]; then
#         print_warning "Affected Slurm/PALS versions detected"
#         log_message "       Jobs with >252 ranks per node may hit libfabric RGID sharing errors"
#         log_message "       Consider earlier Slurm/PALS versions until resolved"
#         log_message "       Related: Issue 2160777, SLURM/PALS >252 Ranks Issue"
#     else
#         print_pass "No affected Slurm/PALS versions detected"
#         log_message "       Note: workload rank counts are not detectable pre-run"
#     fi
    
#     # Check 3: CXI services
#     print_check "Checking CXI service configuration"
#     if command -v cxi_service &> /dev/null; then
#         print_info "CXI service utility found"
#         print_warning "Note: VNI updates on existing CXI services NOT supported in SHS 13.0"
#         log_message "       Related: Issue 3110032"
#     fi
# }

################################################################################
# Slingshot Fabric Checks
################################################################################

check_slingshot_issues() {
    print_header "Slingshot Fabric Issues"

    # Check 1: Certificate Manager Keystore
    print_check "Checking Slingshot Certificate Manager keystore health"
    if [ -d "/var/opt/cray/slingshot" ]; then
        DISK_FULL=$(df -h /var/opt/cray/slingshot | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ "$DISK_FULL" -gt 90 ]; then
            print_fail "Filesystem containing Slingshot cert manager is ${DISK_FULL}% full"
            log_message "       Running fmn-create-certificate with full filesystem can corrupt keystore"
            log_message "       Related: Issue 3039322"
        else
            print_pass "Filesystem space acceptable for certificate operations"
        fi
    fi

    # Check 2: Velero backups
    print_check "Checking Slingshot fabric backup status"
    if command -v kubectl &> /dev/null; then
        VELERO_BACKUPS=$(kubectl get backup -n velero 2>/dev/null | grep slingshot | tail -5)
        if [ -n "$VELERO_BACKUPS" ]; then
            print_info "Recent Slingshot backups found"
            log_message "       Ensure backups are successful before upgrade"
            log_message "       Related: Issue 2300387"
        else
            print_warning "No recent Slingshot fabric backups found via Velero"
            log_message "       Follow 'Backup and restore of fabric configuration' in Slingshot Admin Guide"
        fi
    fi
}

################################################################################
# SMA (System Monitoring Application) Checks
################################################################################

check_sma_issues() {
    print_header "System Monitoring Application (SMA) Issues"

    # Check 1: Helm releases in uninstalling state
    print_check "Checking for stuck Helm releases"
    if command -v helm &> /dev/null; then
        STUCK_RELEASES=$(helm list -A --all 2>/dev/null | grep -i uninstalling | wc -l)
        if [ "$STUCK_RELEASES" -gt 0 ]; then
            print_fail "Found $STUCK_RELEASES Helm releases stuck in 'uninstalling' state"
            log_message "       Particularly check: sma-aiops, sma-opensearch-cron, sma-vm-cluster, sma-monasca"
            log_message "       Manual removal of stale Helm secrets required"
            log_message "       See Section 6.1 Helm operation stuck in uninstalling state"
        else
            print_pass "No Helm releases stuck in uninstalling state"
        fi
    fi

    # Check 2: OpenSearch pods
    print_check "Checking OpenSearch pod health"
    if command -v kubectl &> /dev/null; then
        OPENSEARCH_PODS=$(kubectl get pods -n sma 2>/dev/null | grep opensearch-master | grep -v Running | wc -l)
        if [ "$OPENSEARCH_PODS" -gt 0 ]; then
            print_warning "$OPENSEARCH_PODS OpenSearch master pods not in Running state"
            log_message "       May need attention during upgrade (K8s upgrade issue)"
            log_message "       See Section 6.2.5 OpenSearch Upgrade Issue"
        else
            print_pass "OpenSearch pods healthy"
        fi
    fi

    # Check 3: Kafka topics
    print_check "Checking for required Kafka topics"
    if command -v kubectl &> /dev/null; then
        if kubectl get pods -n sma 2>/dev/null | grep -q cluster-kafka-0; then
            METRIC_TOPIC=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null | grep -c cray-telemetry-metric)
            if [ "$METRIC_TOPIC" -eq 0 ]; then
                print_fail "Required Kafka topic 'cray-telemetry-metric' not found"
                log_message "       May need manual creation after upgrade"
                log_message "       See Missing Kafka Topics section for manual creation steps"
            else
                print_pass "Required Kafka topics present"
            fi
        fi
    fi
    
    # Check 4: LDMS configuration
    print_check "Checking LDMS configuration compatibility"
    LDMS_CONFIG_FOUND=false
    if command -v ldmsd &> /dev/null || command -v ldmsd_controller &> /dev/null; then
        LDMS_CONFIG_FOUND=true
    fi
    if [ -d "/etc/ldms" ] || [ -d "/etc/ldmsd" ]; then
        LDMS_CONFIG_FOUND=true
    fi
    if ls /etc/ldmsd/*.conf &> /dev/null || ls /etc/ldms/*.conf &> /dev/null; then
        LDMS_CONFIG_FOUND=true
    fi

    if [ "$LDMS_CONFIG_FOUND" = true ]; then
        print_warning "LDMS binaries/configs detected"
        log_message "       SMA 1.11.7 includes upgraded LDMS with incompatible config files"
        log_message "       Action required at deliver-product stage"
        log_message "       Should have been handled in CSM 1.6/SMA 1.10 upgrade"
    else
        print_pass "No LDMS binaries/configs detected"
    fi
}

################################################################################
# USS (User Services Software) Checks
################################################################################

##### Can keep for future #######

# check_uss_issues() {
#     print_header "User Services Software (USS) Issues"
    
#     # Check 1: PBS configuration
#     print_check "Checking PBS Professional configuration"
#     if command -v pbsnodes &> /dev/null; then
#         PBS_VERSION=$(pbsnodes --version 2>/dev/null | head -1)
#         print_info "PBS detected: $PBS_VERSION"
#         if [[ "$PBS_VERSION" == *"2024"* ]]; then
#             print_warning "PBS 2024 detected - check for PALS launch issues"
#             log_message "       See Section 13.12.3 PBS PALS launches fail"
#         fi
#         if [[ "$PBS_VERSION" == *"2025.2"* ]]; then
#             print_warning "PBS 2025.2 detected - PBS_cray_atom hook may fail"
#             log_message "       See Section 13.12.4 for http+unix URL scheme issue"
#         fi
#     fi
    
#     # Check 2: Slurm configuration
#     print_check "Checking Slurm configuration"
#     if command -v scontrol &> /dev/null; then
#         SLURM_VERSION=$(scontrol version 2>/dev/null | head -1)
#         print_info "Slurm detected: $SLURM_VERSION"
#         if [[ "$SLURM_VERSION" == *"24.05"* ]]; then
#             print_warning "Slurm 24.05 detected - Instant On support may cause slurmctld failure"
#             log_message "       Update default configuration after upgrade"
#             log_message "       See Section 13.14.6 slurmctld fails to start"
#         fi
#     fi
    
#     # Check 3: cos-config-service
#     print_check "Checking for cos-config-service (to be removed)"
#     if command -v helm &> /dev/null; then
#         if helm list -n services 2>/dev/null | grep -q cos-config-service; then
#             print_warning "cos-config-service is installed and will NOT be auto-removed"
#             log_message "       Must manually uninstall after upgrade:"
#             log_message "       helm uninstall -n services cos-config-service"
#         else
#             print_pass "cos-config-service not installed (expected for new installs)"
#         fi
#     fi
    
#     # Check 4: NMD configuration
#     print_check "Checking Node Memory Dump (NMD) configuration"
#     print_info "If your system has nodes with >80GB memory dumps, update S3 chunk size to 128MB"
#     log_message "       See Section 8.4 Compute node dump upload failure"
    
#     # Check 5: GPU PTX compilation
#     print_check "Checking NVIDIA GPU SDK/Driver compatibility"
#     if [ -d "/opt/nvidia/hpc_sdk" ]; then
#         print_warning "NVIDIA SDK 25.5 (CUDA 12.9) with Driver 570.124.06 (CUDA 12.8) has PTX JIT issues"
#         log_message "       Use CUDA 11.8 modulefiles and paths instead of CUDA 12.9"
#         log_message "       Both versions are in NVIDIA 25.5 SDK"
#     fi
# }

################################################################################
# System Prerequisites
################################################################################

check_system_prerequisites() {
    print_header "System Prerequisites"
    
    # Check 1: Running sessions (BOS, CFS)
    print_check "Checking for running BOS sessions"
    if command -v cray &> /dev/null; then
        RUNNING_BOS=$(cray bos sessions list --format json 2>/dev/null | grep -c "running")
        if [ "$RUNNING_BOS" -gt 0 ]; then
            print_fail "Found $RUNNING_BOS running BOS sessions. Complete them before upgrade."
            log_message "       Check with: cray bos sessions list"
        else
            print_pass "No running BOS sessions"
        fi
    fi

    # Check 2: Check for running CFS sessions
    print_check "Checking for running CFS sessions"
    if command -v cray &> /dev/null; then
        RUNNING_CFS=$(cray cfs sessions list --format json 2>/dev/null | grep -c "running")
        if [ "$RUNNING_CFS" -gt 0 ]; then
            print_fail "Found $RUNNING_CFS running CFS sessions. Complete them before upgrade."
            log_message "       Check with: cray cfs sessions list"
        else
            print_pass "No running CFS sessions"
        fi
    fi
    
    # Check 3: Documentation packages
    print_check "Checking for latest documentation packages"
    if [ -f "/root/docs-csm-latest.noarch.rpm" ] && [ -f "/root/libcsm-latest.noarch.rpm" ]; then
        print_pass "Documentation RPMs found in /root"
    else
        print_warning "Documentation RPMs not found in /root"
        log_message "       Ensure docs-csm-latest.noarch.rpm and libcsm-latest.noarch.rpm are available"
    fi
    
    # Check 4: HSM duplicate events
    print_check "Checking for HSM duplicate detected events"
    if command -v kubectl &> /dev/null; then
        print_info "Run duplicate event cleanup if upgrading from older CSM versions"
        log_message "       See: Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md"
    fi
    
    # Check 5: Switch admin password in vault
    print_check "Checking switch admin password in vault"
    if command -v kubectl &> /dev/null; then
        SWITCH_PASS=$(kubectl get secret -n vault network-switch-password 2>/dev/null)
        if [ $? -eq 0 ]; then
            print_pass "Switch admin password secret exists in vault"
        else
            print_warning "Switch admin password may not be configured in vault"
            log_message "       See: Adding switch admin password to vault"
        fi
    fi
}

################################################################################
# Architecture-Specific Checks
################################################################################

check_architecture_issues() {
    print_header "Architecture-Specific Issues"
    
    # Check 1: aarch64 crash utility
    print_check "Checking crash utility for aarch64 systems"
    ARCH=$(uname -m)
    if [ "$ARCH" == "aarch64" ]; then
        CRASH_VERSION=$(crash --version 2>/dev/null | head -1 | awk '{print $2}')
        if [[ "$CRASH_VERSION" < "8.0.6" ]]; then
            print_warning "crash version $CRASH_VERSION may not support 64KB page size dumps"
            log_message "       Default SLES crash 8.0.4 cannot open 64KB page dumps on aarch64"
            log_message "       Need crash 8.0.6 or compile from source"
        else
            print_pass "crash version $CRASH_VERSION sufficient for aarch64"
        fi
    fi
}

################################################################################
# iSCSI Session Checks (Compute/UAN)
# Reference: Customer advisory for worker node rebuild/rollout
################################################################################

check_iscsi_sessions() {
    print_header "iSCSI Session Checks (Compute/UAN)"
    
    print_check "Collecting iSCSI sessions from compute/UAN nodes"
    if command -v kubectl &> /dev/null; then
        WORKER_NODES=$(kubectl get nodes -l iscsi=sbps -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
        if [ -z "$WORKER_NODES" ]; then
            print_info "No worker nodes found with label iscsi=sbps"
            log_message "       Run: kubectl get nodes -l iscsi=sbps"
        else
            NODE_COUNT=$(echo "$WORKER_NODES" | wc -w | tr -d ' ')
            print_warning "Found $NODE_COUNT worker nodes with iscsi=sbps label"
            log_message "       Worker node list used for expected iSCSI session targets"
        fi

        COMPUTE_NODES=""
        UAN_NODES=""
        if command -v sat &> /dev/null; then
            COMPUTE_NODES=$(sat status --fields xname --filter 'Role=Compute' --no-borders --no-headings 2>/dev/null | awk 'NF' | tr '\n' ' ')
            log_message "       Source: sat status --fields xname --filter 'Role=Compute'"
            UAN_NODES=$(sat status --fields xname --filter 'Role=Application' --no-borders --no-headings 2>/dev/null | awk 'NF' | tr '\n' ' ')
            log_message "       Source: sat status --fields xname --filter 'Role=Application'"
        else
            print_warning "sat not available; cannot list compute nodes in this environment"
        fi

        COMPUTE_NODES=$(echo "$COMPUTE_NODES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
        UAN_NODES=$(echo "$UAN_NODES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
        COMPUTE_UAN_NODES=$(echo "$COMPUTE_NODES $UAN_NODES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
        if [ -z "$COMPUTE_UAN_NODES" ]; then
            print_warning "No compute or UAN nodes found"
            log_message "       Expected sources: sat status --fields xname --filter 'Role=Compute' and sat status --fields xname --filter 'Role=Application'"
        else
            for node in $COMPUTE_UAN_NODES; do
                print_info "Node: $node"
                if ssh -o BatchMode=yes -o ConnectTimeout=5 "$node" "command -v iscsiadm" &> /dev/null; then
                    SESSION_COUNT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$node" "iscsiadm -m session 2>/dev/null | wc -l" | tr -d ' ')
                    log_message "       iscsiadm -m session count: ${SESSION_COUNT:-0}"
                else
                    print_warning "iscsiadm not available on $node or SSH failed"
                fi
            done
            print_info "Customer guidance: delete iSCSI sessions for worker nodes being rebuilt/rolled out from all compute/UAN nodes"
        fi
    else
        print_warning "kubectl not available, cannot list worker nodes"
    fi
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    print_header "Pre-Upgrade Check Summary"
    
    log_message "\nTotal Checks: $TOTAL_CHECKS"
    log_message "${GREEN}Passed: $PASSED_CHECKS${NC}"
    log_message "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    log_message "${RED}Failed: $FAILED_CHECKS${NC}"
    
    log_message "\n${BLUE}Log file: $LOG_FILE${NC}"
    
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        log_message "\n${RED}⚠ CRITICAL: $FAILED_CHECKS checks failed. Address these issues before proceeding with upgrade.${NC}"
        return 1
    elif [ "$WARNING_CHECKS" -gt 0 ]; then
        log_message "\n${YELLOW}⚠ ATTENTION: $WARNING_CHECKS warnings found. Review before proceeding with upgrade.${NC}"
        return 2
    else
        log_message "\n${GREEN}✓ All checks passed. System appears ready for upgrade.${NC}"
        return 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse arguments
    while getopts "hm:" opt; do
        case ${opt} in
            h)
                print_usage
                exit 0
                ;;
            m)
                set_mode "${OPTARG}"
                ;;
            ?)
                print_usage
                exit 1
                ;;
        esac
    done

    log_message "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    log_message "${BLUE}║  CSM Pre-Install / Pre-Upgrade Check Script                    ║${NC}"
    log_message "${BLUE}║  Mode: ${SCRIPT_MODE}                                          ║${NC}"
    log_message "${BLUE}║  Target: CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)               ║${NC}"
    log_message "${BLUE}║  Read-Only: This script performs checks only                   ║${NC}"
    log_message "${BLUE}║  Date: $(date)                                                 ║${NC}"
    log_message "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    # Run all checks
    check_system_prerequisites
    check_kubernetes_health
    check_ceph_health
    check_postgres_health
    check_spire_health
    check_network_services
    check_csm_services_health
    check_hms_services
    check_hardware_health
    check_csm_issues
    check_csm_17_specific
    check_csm_diags_issues
    check_hfp_issues
    # check_shs_issues
    check_slingshot_issues
    check_sma_issues
    # check_uss_issues
    check_architecture_issues
    check_iscsi_sessions
    
    # Print summary
    print_summary
    exit_code=$?
    
    exit $exit_code
}

# Run main function
main
