# CSM Automated Fix Runner - Complete Guide

This toolset automatically detects issues from pre-upgrade check logs, searches the Cray-HPE/docs-csm repository for workarounds, and suggests or executes fixes.

## Overview

The system consists of three main components working together:

```
Pre-Upgrade Logs
    ↓
[log_parser_workarounds.sh] → Extract issues and references
    ↓
[issues.workarounds.json] → Structured issue data
    ↓
[github_docs_searcher.sh] → Search docs-csm repo for fixes
    ↓
[fixes.json] → Extracted commands and workarounds
    ↓
[csm_automated_fix_runner.sh] → Apply fixes with safety checks
    ↓
Execution Log + Report
```

## Component Scripts

### 1. log_parser_workarounds.sh

**Purpose**: Parse pre-upgrade check logs and extract workaround suggestions.

**Usage**:
```bash
./log_parser_workarounds.sh -l <log_file> [-o <output_json>] [-v]
```

**Options**:
- `-l` : Path to pre-upgrade check log file (required)
- `-o` : Output JSON file (default: `<logfile>.workarounds.json`)
- `-v` : Verbose output

**Example**:
```bash
./log_parser_workarounds.sh -l pre_upgrade_checks_20260217_120000.log
```

**Output Format**:
```json
{
  "issues": [
    {
      "type": "FAIL|WARNING|INFO",
      "check": "Check name",
      "message": "Issue description",
      "pattern_key": "kafka_crd|spire_pod|etc",
      "references": [
        "troubleshooting/known_issues/...",
        "operations/..."
      ]
    }
  ],
  "summary": {
    "total": 15,
    "failed": 5,
    "warnings": 10
  }
}
```

### 2. github_docs_searcher.sh

**Purpose**: Search GitHub docs-csm repository for documentation and extract suggested fixes.

**Usage**:
```bash
./github_docs_searcher.sh -i <issues_json> [-o <output_json>] [-t <github_token>] [-v]
```

**Options**:
- `-i` : Input JSON from log_parser (required)
- `-o` : Output JSON file (default: `<input>.fixes.json`)
- `-t` : GitHub API token (or use `GITHUB_TOKEN` env var)
- `-v` : Verbose output

**Examples**:

Without token (limited API rate):
```bash
./github_docs_searcher.sh -i issues.workarounds.json
```

With GitHub token (higher rate limit):
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./github_docs_searcher.sh -i issues.workarounds.json
```

**Output Format**:
```json
{
  "issues_with_fixes": [
    {
      "type": "FAIL",
      "check": "Checking Kafka CRD issues",
      "message": "Kafka CRD conflict detected",
      "pattern_key": "kafka_crd",
      "doc_found": true,
      "doc_urls": [
        "https://github.com/Cray-HPE/docs-csm/blob/master/troubleshooting/..."
      ],
      "fixes": [
        "kubectl apply -f /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh",
        "kubectl patch crd kafkas.kafka.strimzi.io --type merge..."
      ]
    }
  ],
  "summary": {
    "total_issues": 15,
    "found_docs": 12,
    "found_fixes": 8
  }
}
```

### 3. csm_automated_fix_runner.sh

**Purpose**: Orchestrate the complete workflow and execute fixes with safety checks.

**Usage**:
```bash
./csm_automated_fix_runner.sh -l <log_file> [OPTIONS]
```

**Options**:
- `-l` : Pre-upgrade check log file (required)
- `-o` : Output directory (default: current directory)
- `-d` : Dry-run mode (show fixes without executing) - **DEFAULT**
- `-x` : Execute fixes mode (enables execution)
- `-a` : Auto-apply all fixes without prompting
- `-t` : GitHub API token
- `-v` : Verbose output
- `-h` : Show help

**Modes**:

#### Dry-Run Mode (Safe Review - Default)
```bash
./csm_automated_fix_runner.sh -l pre_upgrade_checks.log
```
Shows what fixes would be applied without executing them.

#### Interactive Mode (Ask Before Each Fix)
```bash
./csm_automated_fix_runner.sh -l pre_upgrade_checks.log -x
```
Prompts for confirmation before applying each fix.

#### Auto-Apply Mode (Full Automation)
```bash
./csm_automated_fix_runner.sh -l pre_upgrade_checks.log -x -a
```
Applies all fixes automatically. Destructive commands still require confirmation.

## Complete Workflow Examples

### Example 1: Review Issues Before Upgrade

```bash
# Step 1: Generate pre-upgrade check log
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade_20260217.log

# Step 2: Run automated fix runner in dry-run mode (default)
cd /tmp/csm-analysis
/path/to/csm_automated_fix_runner.sh -l pre_upgrade_20260217.log -v

# Outputs:
# - issues_20260217_120000.workarounds.json
# - fixes_20260217_120000.json
# - csm_fix_report_20260217_120000.md
# - /var/log/csm-fixes/fix_execution_20260217_120000.log
```

### Example 2: Automatically Fix All Issues

```bash
# Set GitHub token for better API access
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Run in auto-apply mode
/path/to/csm_automated_fix_runner.sh \
    -l pre_upgrade_checks.log \
    -x \
    -a \
    -o /tmp/csm-fixes \
    -v

# Check execution log
tail -f /var/log/csm-fixes/fix_execution_*.log
```

### Example 3: Interactive Fix Application

```bash
# Generate logs
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log

# Parse and review
./log_parser_workarounds.sh -l pre_upgrade.log

# Search for fixes
./github_docs_searcher.sh -i pre_upgrade.workarounds.json

# Apply interactively
./csm_automated_fix_runner.sh -l pre_upgrade.log -x
# System will prompt: "Apply these fixes? (y/n/skip)" for each issue
```

## Supported Issues and Fixes

The system recognizes and can fix:

| Issue | Pattern Key | Workaround |
|-------|-------------|-----------|
| Kafka CRD conflicts | `kafka_crd` | Run CRD fix script |
| Nexus storage space | `nexus_space` | Scale PVC or cleanup |
| Spire pod issues | `spire_pod` | Restart pods, check logs |
| PostgreSQL health | `postgres_health` | Run Patroni recovery |
| Ceph cluster issues | `ceph_health` | Balance OSDs, heal cluster |
| MetalLB IP allocation | `metallb_ip` | Check BGP, assign IPs |
| HSM duplicate events | `hsm_events` | Clean duplicate events |
| Certificate expiration | `certificate` | Rotate certificates |
| CNI migration | `cni_migration` | Weave to Cilium preparation |
| LDMS configuration | `ldms_config` | Update config compatibility |

## Safety Features

### Dry-Run Mode
All scripts default to dry-run, showing what would happen without making changes.

### Destructive Command Detection
Commands containing: `delete`, `remove`, `rm -rf`, `drop`, `truncate`, `uninstall`
require explicit "yes" confirmation even in auto-apply mode.

### Execution Logging
All executed commands are logged to:
```
/var/log/csm-fixes/fix_execution_YYYYMMDD_HHMMSS.log
```

### Pre-Execution Validation
- Checks for required commands (kubectl, jq, curl)
- Validates Kubernetes cluster connectivity
- Verifies GitHub API access

## Output Files

After running the complete workflow, you get:

| File | Content |
|------|---------|
| `issues_*.workarounds.json` | Parsed issues from logs |
| `fixes_*.json` | Extracted fixes from documentation |
| `csm_fix_report_*.md` | Human-readable report |
| `/var/log/csm-fixes/fix_execution_*.log` | Execution details |

## Troubleshooting

### GitHub API Rate Limit
```bash
# Use a personal access token for higher limits
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./github_docs_searcher.sh -i issues.json
```

### Missing Dependencies
```bash
# Install required tools
# macOS
brew install jq curl

# CentOS/RHEL
yum install jq curl

# Ubuntu/Debian
apt-get install jq curl
```

### Debug Mode
```bash
# Run with verbose output
./csm_automated_fix_runner.sh -l pre_upgrade.log -v -x
```

### Manual Log Review
```bash
# View execution log
cat /var/log/csm-fixes/fix_execution_*.log

# Search for errors
grep ERROR /var/log/csm-fixes/fix_execution_*.log

# Follow live execution
tail -f /var/log/csm-fixes/fix_execution_*.log
```

## GitHub Token Generation

To get a GitHub token for better API access:

1. Go to https://github.com/settings/tokens
2. Click "Generate new token"
3. Select scope: `public_repo` (for public repo access)
4. Copy and use:
   ```bash
   export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
   ```

## Advanced Usage

### Integration with CI/CD

```bash
# In your upgrade pipeline
./csm_automated_fix_runner.sh \
    -l pre_upgrade_checks.log \
    -x \
    -a \
    -t "$GITHUB_TOKEN" \
    -o "$UPGRADE_STAGING_DIR"

# Check status
if [ -f "/var/log/csm-fixes/fix_execution_"*.log ]; then
    if grep -q "ERROR" /var/log/csm-fixes/fix_execution_*.log; then
        echo "Fixes failed, check log"
        exit 1
    fi
fi
```

### Custom Fix Application

You can create custom issue patterns by editing the script:

```bash
# Edit log_parser_workarounds.sh
# Add to ISSUE_PATTERNS array:
ISSUE_PATTERNS["my_custom_issue"]="pattern.*to.*match"
REFERENCE_MAPPING["my_custom_issue"]="path/to/docs.md"
```

## Best Practices

1. **Always start in dry-run mode**: Review what fixes will be applied
2. **Use GitHub tokens**: Avoid API rate limiting
3. **Run during maintenance window**: Some fixes may affect cluster
4. **Keep execution logs**: For audit and troubleshooting
5. **Test in non-production first**: Validate fixes before production
6. **Review generated reports**: Understand all changes being made

## Support and Feedback

For issues or improvements:
- Check `/var/log/csm-fixes/` for execution details
- Review `csm_fix_report_*.md` for comprehensive analysis
- Refer to https://github.com/Cray-HPE/docs-csm for full documentation
