#!/bin/bash
################################################################################
# Test and Example Generator for CSM Automated Fix Runner
# 
# This script generates sample logs, test data, and demonstrates the
# complete workflow without requiring an actual CSM pre-upgrade run.
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/csm-fix-runner-test"
COLORS_ENABLED=true

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

################################################################################
# Generate Sample Pre-Upgrade Log
################################################################################

generate_sample_log() {
    local output_file="$1"
    
    print_step "Generating sample pre-upgrade check log..."
    
    cat > "$output_file" <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║  CSM Pre-Install / Pre-Upgrade Check Script                   ║
║  Mode: pre-upgrade                                             ║
║  Target: CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)             ║
║  Read-Only: This script performs checks only                  ║
║  Date: Tue Feb 17 12:00:00 CST 2026                           ║
╚════════════════════════════════════════════════════════════════╝

========================================
CSM Core Issues
========================================

[CHECK 1] Checking Nexus storage space
⚠ WARNING: Nexus PVC usage high (85%)
       Reference: troubleshooting/known_issues/nexus_storage.md
       Suggested action: Scale PVC or clean old artifacts

[CHECK 2] Checking for Kafka CRD issues
✗ FAIL: Kafka CRD conflict detected
       Script location: /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh
       Reference: troubleshooting/known_issues/kafka_crd_issue.md

========================================
Kubernetes Cluster Health
========================================

[CHECK 3] Checking Kubernetes node status
✓ PASS: All Kubernetes nodes Ready

[CHECK 4] Checking critical system pods
⚠ WARNING: Pod cray-spire-server-0 restarting frequently
       Reference: troubleshooting/known_issues/spire_pod_initializing.md
       Reference: operations/spire/

========================================
Ceph Storage Health
========================================

[CHECK 5] Checking Ceph cluster health
✓ PASS: Ceph cluster HEALTH_OK

[CHECK 6] Checking Ceph OSD status
✓ PASS: All OSDs are up

========================================
PostgreSQL Database Health
========================================

[CHECK 7] Checking PostgreSQL cluster status
✗ FAIL: PostgreSQL cluster unhealthy - check Patroni status
       Reference: operations/kubernetes/Troubleshoot_Postgres_Database.md
       Reference: troubleshooting/known_issues/postgres_patroni_recovery.md

[CHECK 8] Checking Patroni cluster health
⚠ WARNING: Patroni cluster has 1 replica out of sync
       Reference: troubleshooting/known_issues/postgres_*.md

========================================
Network Services Health
========================================

[CHECK 9] Checking MetalLB IP allocation
⚠ WARNING: LoadBalancer service waiting for IP allocation
       Reference: troubleshooting/known_issues/metallb_bgp.md
       Reference: operations/network/metallb_bgp/

[CHECK 10] Checking CoreDNS pods
✓ PASS: CoreDNS healthy (2 pods)

========================================
CSM 1.7 Specific Pre-Checks
========================================

[CHECK 11] Checking current CNI (Weave → Cilium migration in 1.7)
⚠ WARNING: Current CNI is Weave, will migrate to Cilium in 1.7
       Reference: troubleshooting/known_issues/cni_migration.md
       Reference: introduction/csi_Tool_Changes.md

[CHECK 12] Checking BSS global metadata for Cilium migration
ℹ INFO: BSS metadata exists, will be updated for Cilium

[CHECK 13] Checking Vault token configuration
⚠ WARNING: Old Vault tokens may need cleanup
       Old tokens can cause upgrade issues

========================================
System Prerequisites
========================================

[CHECK 14] Checking HSM duplicate detected events
⚠ WARNING: Potential duplicate events in HSM database
       Reference: troubleshooting/known_issues/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md

[CHECK 15] Checking switch admin password in vault
ℹ INFO: Switch admin password verified in vault

Pre-Upgrade Check Summary
========================================
Total Checks: 15
✓ Passed: 7
⚠ Warnings: 7
✗ Failed: 1

Log file: /etc/cray/upgrade/csm/pre-checks/pre_upgrade_checks_20260217_120000.log
EOF
    
    print_info "Sample log created: $output_file"
}

################################################################################
# Generate Sample Workarounds JSON
################################################################################

generate_sample_workarounds() {
    local output_file="$1"
    
    print_step "Generating sample workarounds JSON..."
    
    cat > "$output_file" <<'EOF'
{
  "issues": [
    {
      "type": "FAIL",
      "check": "Checking for Kafka CRD issues",
      "message": "Kafka CRD conflict detected",
      "pattern_key": "kafka_crd",
      "references": [
        "troubleshooting/known_issues/kafka_crd_issue.md",
        "scripts/kafka_crd_fix.sh"
      ]
    },
    {
      "type": "FAIL",
      "check": "Checking PostgreSQL cluster status",
      "message": "PostgreSQL cluster unhealthy - check Patroni status",
      "pattern_key": "postgres_health",
      "references": [
        "operations/kubernetes/Troubleshoot_Postgres_Database.md",
        "troubleshooting/known_issues/postgres_patroni_recovery.md"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking Nexus storage space",
      "message": "Nexus PVC usage high (85%)",
      "pattern_key": "nexus_space",
      "references": [
        "troubleshooting/known_issues/nexus_storage.md",
        "operations/utility_storage/"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking critical system pods",
      "message": "Pod cray-spire-server-0 restarting frequently",
      "pattern_key": "spire_pod",
      "references": [
        "troubleshooting/known_issues/spire_pod_initializing.md",
        "operations/spire/"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking MetalLB IP allocation",
      "message": "LoadBalancer service waiting for IP allocation",
      "pattern_key": "metallb_ip",
      "references": [
        "troubleshooting/known_issues/metallb_bgp.md",
        "operations/network/metallb_bgp/"
      ]
    }
  ],
  "summary": {
    "total": 5,
    "failed": 2,
    "warnings": 3
  }
}
EOF
    
    print_info "Sample workarounds JSON created: $output_file"
}

################################################################################
# Generate Sample Fixes JSON
################################################################################

generate_sample_fixes() {
    local output_file="$1"
    
    print_step "Generating sample fixes JSON..."
    
    cat > "$output_file" <<'EOF'
{
  "issues_with_fixes": [
    {
      "type": "FAIL",
      "check": "Checking for Kafka CRD issues",
      "message": "Kafka CRD conflict detected",
      "pattern_key": "kafka_crd",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/troubleshooting/known_issues/kafka_crd_issue.md"
      ],
      "fixes": [
        "bash /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh",
        "kubectl rollout restart -n services deployment/cray-kafka-operator"
      ]
    },
    {
      "type": "FAIL",
      "check": "Checking PostgreSQL cluster status",
      "message": "PostgreSQL cluster unhealthy - check Patroni status",
      "pattern_key": "postgres_health",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/operations/kubernetes/Troubleshoot_Postgres_Database.md"
      ],
      "fixes": [
        "kubectl exec -it -n services deployment/keycloak-postgres-0 -- patronictl list",
        "kubectl rollout restart -n services statefulset/keycloak-postgres"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking Nexus storage space",
      "message": "Nexus PVC usage high (85%)",
      "pattern_key": "nexus_space",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/troubleshooting/known_issues/nexus_storage.md"
      ],
      "fixes": [
        "kubectl exec -it -n nexus deployment/nexus -- rm -rf /nexus-data/repository/releases/*-SNAPSHOT*",
        "kubectl patch pvc nexus-data-pvc -n nexus -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"500Gi\"}}}}'"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking critical system pods",
      "message": "Pod cray-spire-server-0 restarting frequently",
      "pattern_key": "spire_pod",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/troubleshooting/known_issues/spire_pod_initializing.md"
      ],
      "fixes": [
        "kubectl logs -n spire -l app=spire-server --tail=50",
        "kubectl delete pod -n spire cray-spire-server-0"
      ]
    },
    {
      "type": "WARNING",
      "check": "Checking MetalLB IP allocation",
      "message": "LoadBalancer service waiting for IP allocation",
      "pattern_key": "metallb_ip",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/operations/network/metallb_bgp/"
      ],
      "fixes": [
        "kubectl get svc -A | grep '<pending>'",
        "kubectl patch service cray-api-gateway-service -n istio-system -p '{\"spec\":{\"type\":\"LoadBalancer\",\"loadBalancerIP\":\"192.168.1.100\"}}'"
      ]
    }
  ],
  "summary": {
    "total_issues": 5,
    "found_docs": 5,
    "found_fixes": 5
  }
}
EOF
    
    print_info "Sample fixes JSON created: $output_file"
}

################################################################################
# Run Complete Test
################################################################################

run_test() {
    print_header "CSM Automated Fix Runner - Complete Test"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    print_step "Created test directory: $TEMP_DIR"
    
    # Generate sample data
    local log_file="$TEMP_DIR/sample_pre_upgrade.log"
    local workarounds_file="$TEMP_DIR/sample_workarounds.json"
    local fixes_file="$TEMP_DIR/sample_fixes.json"
    
    generate_sample_log "$log_file"
    generate_sample_workarounds "$workarounds_file"
    generate_sample_fixes "$fixes_file"
    
    print_header "Test Data Generated"
    
    echo -e "${BLUE}Sample Files:${NC}"
    echo -e "  Pre-Upgrade Log:     $log_file"
    echo -e "  Workarounds JSON:    $workarounds_file"
    echo -e "  Fixes JSON:          $fixes_file"
    
    print_header "Test Workflow Examples"
    
    print_info "Example 1: Run log parser on sample data"
    echo -e "${YELLOW}Command:${NC}"
    echo "  $SCRIPT_DIR/log_parser_workarounds.sh -l $log_file"
    
    print_info "Example 2: Run GitHub searcher (dry-run, API limited)"
    echo -e "${YELLOW}Command:${NC}"
    echo "  $SCRIPT_DIR/github_docs_searcher.sh -i $workarounds_file"
    
    print_info "Example 3: Run automated fix runner in dry-run mode"
    echo -e "${YELLOW}Command:${NC}"
    echo "  $SCRIPT_DIR/csm_automated_fix_runner.sh -l $log_file -o $TEMP_DIR"
    
    print_info "Example 4: Run with GitHub token for better API access"
    echo -e "${YELLOW}Command:${NC}"
    echo "  export GITHUB_TOKEN='ghp_xxxxxxxxxxxxxxxxxxxx'"
    echo "  $SCRIPT_DIR/csm_automated_fix_runner.sh -l $log_file -x -a"
    
    print_header "Expected Outputs"
    
    echo -e "${GREEN}The test will generate:${NC}"
    echo "  1. issues_*.workarounds.json - Parsed issues from logs"
    echo "  2. fixes_*.json - Extracted fixes from documentation"
    echo "  3. csm_fix_report_*.md - Human-readable report"
    echo "  4. /var/log/csm-fixes/fix_execution_*.log - Execution log"
    
    print_header "Quick Start"
    
    print_info "To run the complete workflow with sample data:"
    echo ""
    echo "  cd $TEMP_DIR"
    echo "  $SCRIPT_DIR/csm_automated_fix_runner.sh -l sample_pre_upgrade.log -v"
    echo ""
    echo "  Review dry-run output, then run with -x to execute:"
    echo "  $SCRIPT_DIR/csm_automated_fix_runner.sh -l sample_pre_upgrade.log -x -v"
    echo ""
}

################################################################################
# Display Documentation
################################################################################

show_documentation() {
    print_header "CSM Automated Fix Runner - Usage Guide"
    
    cat <<'EOF'
OVERVIEW
========
This toolset automatically:
1. Parses pre-upgrade check logs to identify issues
2. Searches GitHub Cray-HPE/docs-csm for workarounds
3. Extracts and executes suggested fixes safely

COMPONENTS
==========
1. log_parser_workarounds.sh
   - Input:  Pre-upgrade check log file
   - Output: JSON with parsed issues and references

2. github_docs_searcher.sh
   - Input:  JSON with parsed issues
   - Output: JSON with extracted fixes from documentation

3. csm_automated_fix_runner.sh
   - Input:  Pre-upgrade check log file
   - Output: Applied fixes and execution log
   - Orchestrates the complete workflow

WORKFLOW MODES
==============
• Dry-Run (default):  Show what fixes would be applied
• Interactive (-x):   Prompt before each fix
• Auto-Apply (-x -a): Apply all fixes automatically

SAFETY FEATURES
===============
✓ Dry-run mode enabled by default
✓ Destructive commands require confirmation
✓ All commands logged to /var/log/csm-fixes/
✓ Pre-execution validation of prerequisites
✓ GitHub API rate limit handling

QUICK START
===========
1. Generate logs:
   /opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log

2. Review fixes (dry-run):
   ./csm_automated_fix_runner.sh -l pre_upgrade.log

3. Apply fixes interactively:
   ./csm_automated_fix_runner.sh -l pre_upgrade.log -x

4. Auto-apply all fixes:
   export GITHUB_TOKEN="ghp_..."
   ./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a

OUTPUTS
=======
- issues_*.workarounds.json    : Parsed issues
- fixes_*.json                 : Extracted fixes
- csm_fix_report_*.md          : Summary report
- /var/log/csm-fixes/*.log     : Execution details

SUPPORTED ISSUES
================
✓ Kafka CRD conflicts
✓ Nexus storage issues
✓ Spire pod problems
✓ PostgreSQL health
✓ Ceph storage issues
✓ MetalLB IP allocation
✓ HSM duplicate events
✓ Certificate expiration
✓ CNI migration (Weave→Cilium)
✓ LDMS configuration

TROUBLESHOOTING
===============
GitHub API rate limits:
  export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

Missing dependencies:
  brew install jq curl         # macOS
  apt-get install jq curl      # Ubuntu
  yum install jq curl          # RHEL

Debug mode:
  ./csm_automated_fix_runner.sh -l log.txt -v -x

View execution logs:
  tail -f /var/log/csm-fixes/fix_execution_*.log

DOCUMENTATION
==============
Full README: AUTOMATED_FIX_RUNNER_README.md
GitHub Repo: https://github.com/Cray-HPE/docs-csm

EOF
}

################################################################################
# Main
################################################################################

main() {
    case "${1:-test}" in
        test)
            run_test
            ;;
        docs|help)
            show_documentation
            ;;
        *)
            echo "Usage: $0 [test|docs|help]"
            echo ""
            echo "  test  - Generate sample data and show test workflow"
            echo "  docs  - Display usage documentation"
            echo "  help  - Show this message"
            exit 1
            ;;
    esac
}

main "$@"
