# CSM Automated Fix Runner - Quick Start Guide

## Overview

This toolset **automatically detects issues from pre-upgrade check logs, searches the Cray-HPE/docs-csm repository for workarounds, and suggests or executes fixes**.

```
Pre-Upgrade Logs → Parse Issues → Search GitHub → Extract Fixes → Apply Safely
```

## Installation

All scripts are in `cpv/scripts/`:
- `log_parser_workarounds.sh` - Parse logs for issues
- `github_docs_searcher.sh` - Search GitHub for fixes
- `csm_automated_fix_runner.sh` - Orchestrate complete workflow
- `test_and_examples.sh` - Generate test data

## 60-Second Quick Start

### 1. Generate Pre-Upgrade Check Log
```bash
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log
```

### 2. Run Automated Fix Runner (Review Mode)
```bash
cd cpv/scripts
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log
```

**Output shows:**
- ✗ Failed checks and suggested fixes
- ⚠ Warnings with workarounds
- ✓ Links to documentation

### 3. Apply Fixes (When Ready)
```bash
# Interactive mode - ask before each fix
./csm_automated_fix_runner.sh -l pre_upgrade.log -x

# Or auto-apply all fixes
./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a
```

## Modes Explained

| Mode | Command | When to Use |
|------|---------|-----------|
| **Dry-Run** (default) | `./csm_automated_fix_runner.sh -l log.txt` | Review what will happen |
| **Interactive** | `./csm_automated_fix_runner.sh -l log.txt -x` | Ask before each fix |
| **Auto-Apply** | `./csm_automated_fix_runner.sh -l log.txt -x -a` | Apply all fixes at once |

## Test Without Real Logs

```bash
cd cpv/scripts

# Generate sample test data
./test_and_examples.sh test

# Try the complete workflow with samples
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log -v
```

## What It Detects & Fixes

| Issue | What It Does |
|-------|------------|
| **Kafka CRD conflicts** | Runs fix script, restarts operator |
| **Nexus storage** | Cleans old artifacts, resizes PVC |
| **PostgreSQL unhealthy** | Restarts cluster, checks Patroni |
| **Spire pod issues** | Shows logs, restarts pods |
| **MetalLB pending IPs** | Assigns IPs, configures BGP |
| **HSM duplicate events** | Searches for cleanup script |
| **Certificate expiration** | Suggests rotation commands |
| **CNI migration** | Prepares Weave→Cilium migration |

## Safety Features

✅ **Dry-run by default** - Never modifies anything without `-x`  
✅ **Destructive command warnings** - Extra confirmation for `rm`, `delete`, etc.  
✅ **Full audit logging** - All commands logged to `/var/log/csm-fixes/`  
✅ **Prerequisites check** - Validates kubectl, jq, cluster connectivity  
✅ **GitHub API safety** - Handles rate limits gracefully  

## Common Tasks

### Task 1: Review Issues Before Upgrade
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -v
# Review output, no changes made
```

### Task 2: Fix Critical Issues Only
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -x
# Prompts before each fix - you choose which to apply
```

### Task 3: Full Automated Upgrade Prep
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"  # Optional, for better API access
./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a
# Applies all fixes automatically (except destructive commands)
```

### Task 4: Debug Issues
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -v -x
# Verbose output shows what's happening
# Check /var/log/csm-fixes/ for detailed logs
```

## Output Files

After running, you get:

| File | Contains |
|------|----------|
| `issues_*.workarounds.json` | Parsed issues from your logs |
| `fixes_*.json` | Fixes extracted from GitHub docs |
| `csm_fix_report_*.md` | Readable summary report |
| `/var/log/csm-fixes/fix_execution_*.log` | Detailed execution log |

## Troubleshooting

### "jq not found"
```bash
# Install jq
brew install jq        # macOS
apt-get install jq     # Ubuntu
yum install jq         # RHEL
```

### "GitHub API rate limit"
```bash
# Use a personal access token
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./csm_automated_fix_runner.sh -l log.txt
```

### "Cannot connect to Kubernetes"
```bash
# Run from management node, or
# Set KUBECONFIG pointing to your cluster config
export KUBECONFIG=/path/to/kubeconfig
./csm_automated_fix_runner.sh -l log.txt
```

### "Command failed - see details"
```bash
# Check execution log
tail -100 /var/log/csm-fixes/fix_execution_*.log

# Run in verbose mode
./csm_automated_fix_runner.sh -l log.txt -v -x
```

## Advanced Usage

### Generate GitHub Token (5 minutes)
1. Visit https://github.com/settings/tokens
2. Click "Generate new token"
3. Select `public_repo` scope
4. Copy token: `ghp_xxxxxxxxxxxxxxxxxxxx`
5. Use it:
   ```bash
   export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
   ./csm_automated_fix_runner.sh -l log.txt
   ```

### Integration with Upgrade Scripts
```bash
#!/bin/bash
# In your upgrade pipeline

# Pre-flight checks and fixes
./csm_automated_fix_runner.sh \
    -l pre_upgrade_checks.log \
    -x \
    -a \
    -t "$GITHUB_TOKEN" \
    -o /tmp/upgrade-prep

# Verify all fixes applied
if grep -q "ERROR" /var/log/csm-fixes/fix_execution_*.log; then
    echo "Fixes failed - abort upgrade"
    exit 1
fi

# Continue with upgrade
./cray_upgrade_script.sh
```

### Custom Issue Patterns
Edit `log_parser_workarounds.sh` to add custom issue detection:

```bash
# Add to ISSUE_PATTERNS
ISSUE_PATTERNS["my_issue"]="pattern.*to.*match"
REFERENCE_MAPPING["my_issue"]="path/to/docs.md"
```

## Full Help

```bash
# Log parser
./log_parser_workarounds.sh -h

# GitHub searcher
./github_docs_searcher.sh -h

# Fix runner (main tool)
./csm_automated_fix_runner.sh -h

# Examples and test data
./test_and_examples.sh docs
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `csm_automated_fix_runner.sh` | **Main script - use this** |
| `log_parser_workarounds.sh` | Parse logs (called automatically) |
| `github_docs_searcher.sh` | Search GitHub (called automatically) |
| `AUTOMATED_FIX_RUNNER_README.md` | Full detailed documentation |
| `test_and_examples.sh` | Generate test data and examples |

## Support

- **Full Documentation:** [AUTOMATED_FIX_RUNNER_README.md](AUTOMATED_FIX_RUNNER_README.md)
- **Test Data:** `./test_and_examples.sh test`
- **Example Commands:** `./test_and_examples.sh docs`
- **GitHub Docs:** https://github.com/Cray-HPE/docs-csm

## Best Practices

1. ✓ Always start in **dry-run mode** (default)
2. ✓ Review the **generated report** before applying fixes
3. ✓ Use **GitHub token** to avoid API rate limits
4. ✓ **Keep execution logs** for audit trail
5. ✓ **Test in non-prod first** before production
6. ✓ Run during **maintenance window** (some fixes affect services)

---

**Ready to fix your CSM pre-upgrade issues?**

```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log
```
