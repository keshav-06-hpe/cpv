#!/bin/bash
################################################################################
# GitHub Docs-CSM Searcher
# Purpose: Search Cray-HPE/docs-csm repository for workaround solutions
# 
# This script searches the docs-csm repository for documentation on identified
# issues and extracts suggested fixes and commands.
################################################################################

set -euo pipefail

# GitHub API settings
GITHUB_API="https://api.github.com"
GITHUB_REPO="Cray-HPE/docs-csm"
GITHUB_BRANCH="master"  # or "main"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Cache directory
CACHE_DIR="/tmp/docs-csm-cache"
CACHE_TTL=3600  # 1 hour

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false

################################################################################
# Help
################################################################################

print_usage() {
    cat <<EOF
Usage: $(basename "$0") -i <issues_json> [-o <output_json>] [-t <github_token>] [-v]

Options:
  -i    Input JSON file with parsed issues (from log_parser_workarounds.sh)
  -o    Output JSON file with extracted fixes (default: fixes.json)
  -t    GitHub API token (or set GITHUB_TOKEN env var)
  -v    Verbose output
  -h    Show this help message

This script searches GitHub docs-csm repository for:
  - Documentation on identified issues
  - Suggested fixes and workarounds
  - Commands to run
  - Script locations and references
EOF
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

################################################################################
# GitHub API functions
################################################################################

github_search_code() {
    local query="$1"
    local path="${2:-}"
    
    log_verbose "Searching GitHub: $query in $path"
    
    local url="${GITHUB_API}/search/code?q=repo:${GITHUB_REPO}+${query}"
    if [ -n "$path" ]; then
        url="${url}+path:${path}"
    fi
    
    local headers=""
    if [ -n "$GITHUB_TOKEN" ]; then
        headers="-H \"Authorization: token ${GITHUB_TOKEN}\""
    fi
    
    # Execute search with rate limit handling
    local response=$(curl -s $headers "$url" 2>/dev/null || echo "{}")
    echo "$response"
}

github_get_file_content() {
    local file_path="$1"
    
    log_verbose "Fetching GitHub file: $file_path"
    
    local url="${GITHUB_API}/repos/${GITHUB_REPO}/contents/${file_path}?ref=${GITHUB_BRANCH}"
    
    local headers=""
    if [ -n "$GITHUB_TOKEN" ]; then
        headers="-H \"Authorization: token ${GITHUB_TOKEN}\""
    fi
    
    local response=$(curl -s $headers "$url" 2>/dev/null || echo "{}")
    
    # Decode base64 content
    if echo "$response" | jq -e '.content' &>/dev/null; then
        echo "$response" | jq -r '.content' | base64 -d 2>/dev/null || echo ""
    else
        echo ""
    fi
}

################################################################################
# Extract fixes from documentation
################################################################################

extract_fixes_from_docs() {
    local doc_content="$1"
    local issue_key="$2"
    
    local fixes=()
    
    # Pattern 1: Commands to run
    if [[ "$doc_content" =~ \`\`\`bash(.*?)\`\`\` ]]; then
        local cmd_block="${BASH_REMATCH[1]}"
        while IFS= read -r cmd; do
            if [ -n "$cmd" ] && [[ ! "$cmd" =~ ^# ]]; then
                fixes+=("$cmd")
            fi
        done <<< "$cmd_block"
    fi
    
    # Pattern 2: kubectl commands
    while IFS= read -r line; do
        if [[ "$line" =~ kubectl.* ]]; then
            fixes+=("$line")
        fi
    done <<< "$doc_content"
    
    # Pattern 3: helm commands
    while IFS= read -r line; do
        if [[ "$line" =~ helm.* ]]; then
            fixes+=("$line")
        fi
    done <<< "$doc_content"
    
    # Pattern 4: cray CLI commands
    while IFS= read -r line; do
        if [[ "$line" =~ cray\ .* ]]; then
            fixes+=("$line")
        fi
    done <<< "$doc_content"
    
    # Return unique fixes
    printf '%s\n' "${fixes[@]}" | sort -u
}

################################################################################
# Process issues and search for fixes
################################################################################

process_issues() {
    local input_json="$1"
    local output_json="$2"
    
    if [ ! -f "$input_json" ]; then
        echo -e "${RED}Error: Input JSON not found: $input_json${NC}" >&2
        return 1
    fi
    
    log_verbose "Processing issues from: $input_json"
    
    mkdir -p "$CACHE_DIR"
    
    local output='{"issues_with_fixes": [], "summary": {"total_issues": 0, "found_docs": 0, "found_fixes": 0}}'
    
    local issue_count=$(jq '.issues | length' "$input_json")
    log_verbose "Found $issue_count issues to process"
    
    for ((i=0; i<issue_count; i++)); do
        local issue=$(jq ".issues[$i]" "$input_json")
        local issue_type=$(echo "$issue" | jq -r '.type')
        local check_name=$(echo "$issue" | jq -r '.check')
        local message=$(echo "$issue" | jq -r '.message')
        local pattern_key=$(echo "$issue" | jq -r '.pattern_key')
        local references=$(echo "$issue" | jq -r '.references[]' 2>/dev/null || echo "")
        
        log_verbose "Processing issue: $check_name ($pattern_key)"
        
        local issue_output=$(jq -n \
            --arg type "$issue_type" \
            --arg check "$check_name" \
            --arg message "$message" \
            --arg pattern_key "$pattern_key" \
            '{type: $type, check: $check, message: $message, pattern_key: $pattern_key, fixes: [], doc_found: false, doc_urls: []}')
        
        # Search for each reference
        local found_doc=false
        local all_fixes=()
        
        while IFS= read -r ref; do
            if [ -z "$ref" ]; then continue; fi
            
            log_verbose "  Searching for reference: $ref"
            
            # Try to fetch the document
            local doc_content=$(github_get_file_content "$ref")
            
            if [ -n "$doc_content" ]; then
                found_doc=true
                log_verbose "  Found documentation for: $ref"
                
                # Extract fixes from this document
                local fixes=$(extract_fixes_from_docs "$doc_content" "$pattern_key")
                while IFS= read -r fix; do
                    if [ -n "$fix" ]; then
                        all_fixes+=("$fix")
                    fi
                done <<< "$fixes"
                
                # Add to issue output
                issue_output=$(echo "$issue_output" | jq \
                    --arg url "https://github.com/${GITHUB_REPO}/blob/${GITHUB_BRANCH}/${ref}" \
                    '.doc_urls += [$url]')
            fi
        done <<< "$(echo "$references")"
        
        # Add fixes to issue
        if [ ${#all_fixes[@]} -gt 0 ]; then
            issue_output=$(echo "$issue_output" | jq --arg fixes "$(printf '%s\n' "${all_fixes[@]}")" \
                '.fixes = ($fixes | split("\n") | map(select(length > 0)))')
        fi
        
        issue_output=$(echo "$issue_output" | jq --arg found "$found_doc" '.doc_found = ($found == "true")')
        
        output=$(echo "$output" | jq ".issues_with_fixes += [$issue_output]")
        output=$(echo "$output" | jq '.summary.total_issues += 1')
        
        if [ "$found_doc" = true ]; then
            output=$(echo "$output" | jq '.summary.found_docs += 1')
        fi
        
        if [ ${#all_fixes[@]} -gt 0 ]; then
            output=$(echo "$output" | jq '.summary.found_fixes += 1')
        fi
    done
    
    echo "$output" | jq '.' > "$output_json"
    
    # Print summary
    local total=$(echo "$output" | jq '.summary.total_issues')
    local found_docs=$(echo "$output" | jq '.summary.found_docs')
    local found_fixes=$(echo "$output" | jq '.summary.found_fixes')
    
    echo -e "${GREEN}GitHub search complete:${NC}"
    echo -e "  Total issues: $total"
    echo -e "  ${GREEN}Found docs: $found_docs${NC}"
    echo -e "  ${GREEN}Found fixes: $found_fixes${NC}"
    echo -e "  ${BLUE}Output: $output_json${NC}"
}

################################################################################
# Main
################################################################################

main() {
    local input_json=""
    local output_json=""
    
    while getopts "i:o:t:vh" opt; do
        case "$opt" in
            i) input_json="$OPTARG" ;;
            o) output_json="$OPTARG" ;;
            t) GITHUB_TOKEN="$OPTARG" ;;
            v) VERBOSE=true ;;
            h) print_usage; exit 0 ;;
            *) print_usage; exit 1 ;;
        esac
    done
    
    if [ -z "$input_json" ]; then
        echo -e "${RED}Error: Input JSON required (-i)${NC}" >&2
        print_usage
        exit 1
    fi
    
    if [ -z "$output_json" ]; then
        output_json="${input_json%.json}.fixes.json"
    fi
    
    # Check for required commands
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}Error: $cmd is required but not installed${NC}" >&2
            exit 1
        fi
    done
    
    process_issues "$input_json" "$output_json"
}

main "$@"
