#!/bin/bash
################################################################################
# Log Parser for CSM Pre-Upgrade Checks
# Purpose: Parse pre-upgrade check logs and extract workaround suggestions
# 
# This script reads logs from pre_upgrade_new_checks.sh and extracts:
# - Failed checks requiring workarounds
# - Warning messages with suggested fixes
# - Referenced documentation paths
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output file for parsed workarounds
WORKAROUNDS_JSON=""
VERBOSE=false

################################################################################
# Help and usage
################################################################################

print_usage() {
    cat <<EOF
Usage: $(basename "$0") -l <log_file> [-o <output_json>] [-v]

Options:
  -l    Path to pre-upgrade check log file (required)
  -o    Output JSON file for parsed workarounds (default: workarounds.json)
  -v    Verbose output
  -h    Show this help message

Output:
  Generates JSON with extracted issues, references, and suggested fixes
  Example structure:
  {
    "issues": [
      {
        "type": "FAIL|WARNING|INFO",
        "check": "Check name",
        "message": "Issue description",
        "references": ["doc/path/1", "doc/path/2"],
        "suggested_fixes": ["fix command 1", "fix command 2"],
        "script_location": "/path/to/fix/script"
      }
    ]
  }
EOF
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

################################################################################
# Workaround Pattern Definitions
################################################################################

# Define known issues and their workarounds
declare -A ISSUE_PATTERNS=(
    ["kafka_crd"]="Kafka CRD|kafka.*issue"
    ["nexus_space"]="Nexus.*space|Nexus.*PVC"
    ["spire_pod"]="Spire.*PodInitializing|spire_pod_initializing"
    ["spire_postgres"]="Spire.*PostgreSQL|spire_postgres"
    ["postgres_health"]="PostgreSQL.*issue|postgres.*unhealthy"
    ["ceph_health"]="Ceph.*unhealthy|Ceph.*HEALTH_ERR"
    ["metallb_ip"]="LoadBalancer.*pending|MetalLB.*IP"
    ["hsm_events"]="HSM.*duplicate.*events|duplicate.*detected.*events"
    ["switch_admin"]="switch.*admin.*password|vault.*switch"
    ["certificate"]="certificate.*expir|cert.*invalid"
    ["cni_migration"]="CNI.*migration|Weave.*Cilium"
    ["bss_metadata"]="BSS.*metadata|Cilium.*metadata"
    ["ldms_config"]="LDMS.*config|LDMS.*compatibility"
)

# References mapping
declare -A REFERENCE_MAPPING=(
    ["kafka_crd"]="troubleshooting/known_issues/kafka_crd_issue.md|scripts/kafka_crd_fix.sh"
    ["nexus_space"]="troubleshooting/known_issues/nexus_storage.md|operations/utility_storage/"
    ["spire_pod"]="troubleshooting/known_issues/spire_pod_initializing.md|operations/spire/"
    ["spire_postgres"]="troubleshooting/known_issues/spire_postgres_*.md|operations/spire/"
    ["postgres_health"]="troubleshooting/known_issues/postgres_*.md|operations/kubernetes/Troubleshoot_Postgres_Database.md"
    ["ceph_health"]="troubleshooting/known_issues/ceph_health.md|operations/utility_storage/"
    ["metallb_ip"]="troubleshooting/known_issues/metallb_*.md|operations/network/metallb_bgp/"
    ["hsm_events"]="troubleshooting/known_issues/Remove_Duplicate_Detected_Events_From_HSM_Postgres_Database.md"
    ["switch_admin"]="troubleshooting/known_issues/switch_admin_password.md"
    ["certificate"]="troubleshooting/known_issues/certificate_expiration.md|operations/kubernetes/certificates/"
    ["cni_migration"]="troubleshooting/known_issues/cni_migration.md|introduction/csi_Tool_Changes.md"
    ["bss_metadata"]="troubleshooting/known_issues/bss_cilium_metadata.md"
    ["ldms_config"]="troubleshooting/known_issues/ldms_config_compatibility.md"
)

################################################################################
# Parse log file
################################################################################

parse_log() {
    local log_file="$1"
    local output_json="$2"
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}Error: Log file not found: $log_file${NC}" >&2
        return 1
    fi

    log_verbose "Parsing log file: $log_file"

    # Initialize JSON output
    local json_output='{"issues": [], "summary": {"total": 0, "failed": 0, "warnings": 0}}'

    # Extract failed checks
    while IFS= read -r line; do
        if [[ "$line" =~ \[CHECK\ ([0-9]+)\]\ (.+)$ ]]; then
            local check_name="${BASH_REMATCH[2]}"
            log_verbose "Found check: $check_name"
        fi

        # Look for FAIL messages
        if [[ "$line" =~ ✗\ FAIL:\ (.+)$ ]]; then
            local issue_msg="${BASH_REMATCH[1]}"
            log_verbose "Found FAIL: $issue_msg"
            
            # Try to match against known patterns
            for pattern_key in "${!ISSUE_PATTERNS[@]}"; do
                if [[ "$issue_msg" =~ ${ISSUE_PATTERNS[$pattern_key]} ]]; then
                    log_verbose "  Matched pattern: $pattern_key"
                    
                    # Extract references from subsequent lines
                    local refs="${REFERENCE_MAPPING[$pattern_key]}"
                    
                    # Build issue object (to be added to JSON)
                    local issue_obj=$(jq -n \
                        --arg type "FAIL" \
                        --arg check "$check_name" \
                        --arg msg "$issue_msg" \
                        --arg pattern_key "$pattern_key" \
                        --arg refs "$refs" \
                        '{type: $type, check: $check, message: $msg, pattern_key: $pattern_key, references: ($refs | split("|"))}')
                    
                    json_output=$(echo "$json_output" | jq ".issues += [$issue_obj]")
                    json_output=$(echo "$json_output" | jq '.summary.total += 1 | .summary.failed += 1')
                    break
                fi
            done
        fi

        # Look for WARNING messages
        if [[ "$line" =~ ⚠\ WARNING:\ (.+)$ ]]; then
            local warning_msg="${BASH_REMATCH[1]}"
            log_verbose "Found WARNING: $warning_msg"
            
            # Try to match against known patterns
            for pattern_key in "${!ISSUE_PATTERNS[@]}"; do
                if [[ "$warning_msg" =~ ${ISSUE_PATTERNS[$pattern_key]} ]]; then
                    log_verbose "  Matched pattern: $pattern_key"
                    
                    local refs="${REFERENCE_MAPPING[$pattern_key]}"
                    
                    local issue_obj=$(jq -n \
                        --arg type "WARNING" \
                        --arg check "$check_name" \
                        --arg msg "$warning_msg" \
                        --arg pattern_key "$pattern_key" \
                        --arg refs "$refs" \
                        '{type: $type, check: $check, message: $msg, pattern_key: $pattern_key, references: ($refs | split("|"))}')
                    
                    json_output=$(echo "$json_output" | jq ".issues += [$issue_obj]")
                    json_output=$(echo "$json_output" | jq '.summary.total += 1 | .summary.warnings += 1')
                    break
                fi
            done
        fi

        # Extract script location references
        if [[ "$line" =~ Script\ location:\ (.+)$ ]]; then
            local script_loc="${BASH_REMATCH[1]}"
            log_verbose "Found script location: $script_loc"
            json_output=$(echo "$json_output" | jq ".script_locations += [\"$script_loc\"]" 2>/dev/null || \
                         echo "$json_output" | jq ".script_locations = [\"$script_loc\"]")
        fi

    done < "$log_file"

    # Write output JSON
    echo "$json_output" | jq '.' > "$output_json"
    
    log_verbose "Parsed workarounds saved to: $output_json"
    
    # Print summary
    local total=$(echo "$json_output" | jq '.summary.total')
    local failed=$(echo "$json_output" | jq '.summary.failed')
    local warnings=$(echo "$json_output" | jq '.summary.warnings')
    
    echo -e "${GREEN}Parsing complete:${NC}"
    echo -e "  Total issues: $total"
    echo -e "  ${RED}Failed: $failed${NC}"
    echo -e "  ${YELLOW}Warnings: $warnings${NC}"
    echo -e "  ${BLUE}Output: $output_json${NC}"
}

################################################################################
# Main
################################################################################

main() {
    local log_file=""
    
    while getopts "l:o:vh" opt; do
        case "$opt" in
            l) log_file="$OPTARG" ;;
            o) WORKAROUNDS_JSON="$OPTARG" ;;
            v) VERBOSE=true ;;
            h) print_usage; exit 0 ;;
            *) print_usage; exit 1 ;;
        esac
    done

    if [ -z "$log_file" ]; then
        echo -e "${RED}Error: Log file required (-l)${NC}" >&2
        print_usage
        exit 1
    fi

    # Set default output if not provided
    if [ -z "$WORKAROUNDS_JSON" ]; then
        WORKAROUNDS_JSON="${log_file%.log}.workarounds.json"
    fi

    # Check for required commands
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}" >&2
        exit 1
    fi

    parse_log "$log_file" "$WORKAROUNDS_JSON"
}

main "$@"
