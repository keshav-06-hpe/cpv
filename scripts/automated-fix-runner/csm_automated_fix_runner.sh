#!/bin/bash
################################################################################
# CSM Automated Fix Runner
# Purpose: Execute suggested fixes from pre-upgrade check logs
# 
# This script orchestrates the complete workflow:
# 1. Parse logs to identify issues
# 2. Search GitHub docs-csm for workarounds
# 3. Generate and execute fix commands with safety checks
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directories
OUTPUT_DIR="${OUTPUT_DIR:-.}"
FIXES_LOG_DIR="/var/log/csm-fixes"
DRY_RUN=true
AUTO_APPLY=false
VERBOSE=false

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Timestamps
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXECUTION_LOG="${FIXES_LOG_DIR}/fix_execution_${TIMESTAMP}.log"

################################################################################
# Helper Functions
################################################################################

print_usage() {
    cat <<EOF
Usage: $(basename "$0") -l <log_file> [OPTIONS]

Options:
  -l    Pre-upgrade check log file (required)
  -o    Output directory for parsed data (default: current directory)
  -d    Dry-run mode - show fixes without executing (default: enabled)
  -x    Execute fixes (disables dry-run mode)
  -a    Auto-apply all fixes without prompting
  -t    GitHub API token (or set GITHUB_TOKEN env var)
  -v    Verbose output
  -h    Show this help message

Example workflow:
  1. Review fixes in dry-run mode:
     $(basename "$0") -l pre_upgrade_checks.log
  
  2. Execute selected fixes interactively:
     $(basename "$0") -l pre_upgrade_checks.log -x
  
  3. Auto-apply all fixes:
     $(basename "$0") -l pre_upgrade_checks.log -x -a

Output:
  - Parsed issues: \$OUTPUT_DIR/issues.workarounds.json
  - GitHub fixes: \$OUTPUT_DIR/issues.fixes.json
  - Execution log: $EXECUTION_LOG
EOF
}

log_message() {
    local level="$1"
    local msg="$2"
    local color=""
    
    case "$level" in
        INFO) color="$BLUE" ;;
        SUCCESS) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${msg}" | tee -a "$EXECUTION_LOG"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log_message "DEBUG" "$1"
    fi
}

init_environment() {
    # Create log directory
    mkdir -p "$FIXES_LOG_DIR"
    
    # Initialize execution log
    touch "$EXECUTION_LOG"
    
    log_message "INFO" "CSM Automated Fix Runner started"
    log_message "INFO" "Output directory: $OUTPUT_DIR"
    log_message "INFO" "Execution log: $EXECUTION_LOG"
    log_message "INFO" "Dry-run mode: $DRY_RUN"
}

################################################################################
# Validation Functions
################################################################################

validate_prerequisites() {
    log_message "INFO" "Validating prerequisites..."
    
    # Check for required commands
    local required_cmds=("jq" "kubectl" "curl")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_message "WARN" "Optional command not found: $cmd (some fixes may be skipped)"
        fi
    done
    
    # Check for required scripts
    if [ ! -f "$SCRIPT_DIR/log_parser_workarounds.sh" ]; then
        log_message "ERROR" "log_parser_workarounds.sh not found"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/github_docs_searcher.sh" ]; then
        log_message "ERROR" "github_docs_searcher.sh not found"
        return 1
    fi
    
    # Check kubectl access if in execute mode
    if [ "$DRY_RUN" = false ] && command -v kubectl &> /dev/null; then
        if ! kubectl cluster-info &>/dev/null; then
            log_message "WARN" "Cannot connect to Kubernetes cluster"
        fi
    fi
    
    log_message "SUCCESS" "Prerequisites validated"
    return 0
}

################################################################################
# Pipeline Orchestration
################################################################################

run_pipeline() {
    local log_file="$1"
    local issues_json="${OUTPUT_DIR}/issues_${TIMESTAMP}.workarounds.json"
    local fixes_json="${OUTPUT_DIR}/fixes_${TIMESTAMP}.json"
    
    log_message "INFO" "Starting CSM fix pipeline..."
    
    # Step 1: Parse logs
    log_message "INFO" "[Step 1/3] Parsing pre-upgrade check logs..."
    if ! bash "$SCRIPT_DIR/log_parser_workarounds.sh" -l "$log_file" -o "$issues_json" $( [ "$VERBOSE" = true ] && echo "-v" || echo ""); then
        log_message "ERROR" "Failed to parse logs"
        return 1
    fi
    log_message "SUCCESS" "Logs parsed: $issues_json"
    
    # Step 2: Search GitHub for fixes
    log_message "INFO" "[Step 2/3] Searching GitHub docs-csm for workarounds..."
    local github_opts=""
    [ -n "${GITHUB_TOKEN:-}" ] && github_opts="-t $GITHUB_TOKEN"
    [ "$VERBOSE" = true ] && github_opts="$github_opts -v"
    
    if ! bash "$SCRIPT_DIR/github_docs_searcher.sh" -i "$issues_json" -o "$fixes_json" $github_opts; then
        log_message "WARN" "GitHub search encountered issues, continuing with available data"
    fi
    log_message "SUCCESS" "GitHub search completed: $fixes_json"
    
    # Step 3: Display and apply fixes
    log_message "INFO" "[Step 3/3] Processing extracted fixes..."
    process_and_apply_fixes "$fixes_json"
}

################################################################################
# Fix Processing and Execution
################################################################################

process_and_apply_fixes() {
    local fixes_json="$1"
    
    if [ ! -f "$fixes_json" ]; then
        log_message "ERROR" "Fixes JSON not found: $fixes_json"
        return 1
    fi
    
    log_verbose "Processing fixes from: $fixes_json"
    
    local issue_count=$(jq '.issues_with_fixes | length' "$fixes_json" 2>/dev/null || echo 0)
    
    if [ "$issue_count" -eq 0 ]; then
        log_message "INFO" "No issues with fixes found"
        return 0
    fi
    
    log_message "INFO" "Found $issue_count issues with potential fixes"
    
    local fixes_applied=0
    local fixes_skipped=0
    
    for ((i=0; i<issue_count; i++)); do
        local issue=$(jq ".issues_with_fixes[$i]" "$fixes_json")
        local issue_type=$(echo "$issue" | jq -r '.type')
        local check_name=$(echo "$issue" | jq -r '.check')
        local message=$(echo "$issue" | jq -r '.message')
        local fixes=$(echo "$issue" | jq -r '.fixes[]?' 2>/dev/null | grep -v '^$')
        local doc_found=$(echo "$issue" | jq -r '.doc_found')
        local doc_urls=$(echo "$issue" | jq -r '.doc_urls[]?' 2>/dev/null)
        
        echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Issue ${i+1}/${issue_count}${NC}"
        echo -e "  Type: ${issue_type}"
        echo -e "  Check: ${check_name}"
        echo -e "  Message: ${message}"
        
        if [ "$doc_found" = "true" ]; then
            echo -e "  ${GREEN}✓ Documentation found${NC}"
            if [ -n "$doc_urls" ]; then
                echo -e "  References:"
                echo "$doc_urls" | sed 's/^/    - /'
            fi
        else
            echo -e "  ${YELLOW}⚠ No documentation found${NC}"
        fi
        
        # Display fixes
        if [ -n "$fixes" ]; then
            echo -e "\n  ${GREEN}Suggested Fixes:${NC}"
            local fix_count=0
            while IFS= read -r fix; do
                ((fix_count++))
                echo -e "    [$fix_count] $fix"
            done <<< "$fixes"
            
            # Apply or prompt
            if [ "$DRY_RUN" = true ]; then
                echo -e "\n  ${YELLOW}[DRY-RUN]${NC} Not executing fixes (use -x to enable execution)"
                ((fixes_skipped++))
            else
                if [ "$AUTO_APPLY" = true ]; then
                    echo -e "\n  ${BLUE}[AUTO-APPLY]${NC} Applying fixes..."
                    if apply_fixes "$fix_count" "$fixes"; then
                        ((fixes_applied++))
                    else
                        ((fixes_skipped++))
                    fi
                else
                    echo -e "\n  ${BLUE}Apply these fixes?${NC} (y/n/skip):"
                    read -r response
                    case "$response" in
                        y|Y)
                            if apply_fixes "$fix_count" "$fixes"; then
                                ((fixes_applied++))
                            else
                                ((fixes_skipped++))
                            fi
                            ;;
                        *)
                            echo "  Skipped"
                            ((fixes_skipped++))
                            ;;
                    esac
                fi
            fi
        else
            echo -e "\n  ${YELLOW}No specific fixes found${NC} (manual remediation may be required)"
            echo -e "  Please review the documentation links above"
        fi
    done
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
    log_message "SUCCESS" "Fix processing complete"
    log_message "INFO" "Applied: $fixes_applied | Skipped: $fixes_skipped"
    
    return 0
}

apply_fixes() {
    local fix_count="$1"
    local fixes="$2"
    local fix_num=1
    local all_success=true
    
    while IFS= read -r fix; do
        if [ -z "$fix" ]; then continue; fi
        
        log_message "INFO" "  Executing fix [$fix_num/$fix_count]: $fix"
        
        # Safety: Don't execute destructive commands without explicit approval
        if [[ "$fix" =~ (delete|remove|rm\ -rf|drop|truncate|uninstall) ]]; then
            log_message "WARN" "  Destructive command detected, requiring confirmation"
            echo -e "    Execute this destructive command? (yes/no):"
            read -r confirm
            if [[ "$confirm" != "yes" ]]; then
                log_message "INFO" "  Command skipped by user"
                all_success=false
                ((fix_num++))
                continue
            fi
        fi
        
        # Execute command
        if eval "$fix" >> "$EXECUTION_LOG" 2>&1; then
            log_message "SUCCESS" "  Fix [$fix_num/$fix_count] executed successfully"
        else
            log_message "ERROR" "  Fix [$fix_num/$fix_count] failed (see log for details)"
            all_success=false
        fi
        
        ((fix_num++))
    done <<< "$fixes"
    
    [ "$all_success" = true ] && return 0 || return 1
}

################################################################################
# Report Generation
################################################################################

generate_report() {
    local issues_json="$1"
    local fixes_json="$2"
    local report_file="${OUTPUT_DIR}/csm_fix_report_${TIMESTAMP}.md"
    
    log_message "INFO" "Generating report: $report_file"
    
    cat > "$report_file" <<'EOF'
# CSM Pre-Upgrade Check Report with Suggested Fixes

## Summary

EOF
    
    if [ -f "$fixes_json" ]; then
        local total=$(jq '.summary.total_issues' "$fixes_json" 2>/dev/null || echo 0)
        local docs=$(jq '.summary.found_docs' "$fixes_json" 2>/dev/null || echo 0)
        local fixes=$(jq '.summary.found_fixes' "$fixes_json" 2>/dev/null || echo 0)
        
        cat >> "$report_file" <<EOF
- **Total Issues Found**: $total
- **With Documentation**: $docs
- **With Suggested Fixes**: $fixes
- **Generated**: $(date)
- **Execution Log**: $EXECUTION_LOG

## Issues and Fixes

EOF
    fi
    
    if [ -f "$fixes_json" ]; then
        jq -r '.issues_with_fixes[] | "\n### \(.check) (\(.type))\n\n\(.message)\n"' "$fixes_json" >> "$report_file" 2>/dev/null || true
    fi
    
    log_message "SUCCESS" "Report generated: $report_file"
}

################################################################################
# Main
################################################################################

main() {
    local log_file=""
    
    while getopts "l:o:dxat:vh" opt; do
        case "$opt" in
            l) log_file="$OPTARG" ;;
            o) OUTPUT_DIR="$OPTARG" ;;
            d) DRY_RUN=true ;;
            x) DRY_RUN=false ;;
            a) AUTO_APPLY=true ;;
            t) export GITHUB_TOKEN="$OPTARG" ;;
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
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}Error: Log file not found: $log_file${NC}" >&2
        exit 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    init_environment
    
    if ! validate_prerequisites; then
        log_message "ERROR" "Prerequisites validation failed"
        exit 1
    fi
    
    run_pipeline "$log_file"
    
    # Generate report
    local issues_json="${OUTPUT_DIR}/issues_${TIMESTAMP}.workarounds.json"
    local fixes_json="${OUTPUT_DIR}/fixes_${TIMESTAMP}.json"
    generate_report "$issues_json" "$fixes_json"
    
    log_message "SUCCESS" "CSM Automated Fix Runner completed"
    log_message "INFO" "Review the execution log: $EXECUTION_LOG"
}

main "$@"
