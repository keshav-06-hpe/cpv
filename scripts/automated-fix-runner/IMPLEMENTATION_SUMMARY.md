# CSM Automated Fix Runner - Implementation Summary

## Overview

You now have a complete **end-to-end automation system** that:

1. **Parses** pre-upgrade check logs to identify issues
2. **Searches** GitHub Cray-HPE/docs-csm for workarounds
3. **Extracts** suggested fixes and commands
4. **Safely executes** fixes with confirmation and logging

## What Was Created

### Core Scripts (in `cpv/scripts/`)

#### 1. `log_parser_workarounds.sh` (480 lines)
**Purpose:** Parse pre-upgrade check logs and extract actionable issues

**Features:**
- Recognizes 13 known issue patterns (Kafka, Spire, PostgreSQL, etc.)
- Extracts FAIL, WARNING, and INFO level issues
- Maps issues to GitHub documentation paths
- Outputs structured JSON for downstream processing
- Handles verbose logging and error cases

**Usage:**
```bash
./log_parser_workarounds.sh -l pre_upgrade.log -o issues.json -v
```

**Output:** JSON with issues, references, and pattern matching

---

#### 2. `github_docs_searcher.sh` (380 lines)
**Purpose:** Search Cray-HPE/docs-csm repository for workarounds

**Features:**
- Uses GitHub API to search and fetch documentation
- Extracts bash, kubectl, helm, and cray CLI commands from docs
- Handles API rate limiting gracefully
- Supports GitHub token for higher rate limits
- Deduplicates extracted commands
- Maps fixes back to source documentation URLs

**Usage:**
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./github_docs_searcher.sh -i issues.json -o fixes.json
```

**Output:** JSON with extracted fixes and documentation links

---

#### 3. `csm_automated_fix_runner.sh` (520 lines) - **Main Script**
**Purpose:** Orchestrate complete workflow and execute fixes safely

**Features:**
- **3 Operating Modes:**
  - Dry-run (default): Shows what would happen
  - Interactive (-x): Prompts before each fix
  - Auto-apply (-x -a): Applies all fixes

- **Safety Mechanisms:**
  - Dry-run enabled by default
  - Destructive commands require extra confirmation
  - Pre-execution validation of prerequisites
  - Full audit logging to `/var/log/csm-fixes/`
  - Handles Kubernetes connectivity checks

- **Workflow Orchestration:**
  1. Validates prerequisites (jq, kubectl, curl, cluster)
  2. Calls log_parser_workarounds.sh
  3. Calls github_docs_searcher.sh
  4. Displays issues with fixes in formatted output
  5. Prompts for or auto-applies fixes
  6. Generates execution report

**Usage:**
```bash
# Review mode (dry-run)
./csm_automated_fix_runner.sh -l pre_upgrade.log

# Interactive mode
./csm_automated_fix_runner.sh -l pre_upgrade.log -x

# Auto-apply mode
./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a -t "$GITHUB_TOKEN"
```

**Output:**
- `issues_*.workarounds.json` - Parsed issues
- `fixes_*.json` - Extracted fixes
- `csm_fix_report_*.md` - Human-readable report
- `/var/log/csm-fixes/fix_execution_*.log` - Execution details

---

#### 4. `test_and_examples.sh` (380 lines)
**Purpose:** Generate test data and demonstrate workflows

**Features:**
- Creates realistic sample pre-upgrade logs
- Generates sample workarounds and fixes JSON
- Shows example commands and workflows
- Includes documentation generator
- Enables testing without real CSM environment

**Usage:**
```bash
# Generate test data
./test_and_examples.sh test

# Show documentation
./test_and_examples.sh docs

# Show help
./test_and_examples.sh help
```

---

### Documentation Files

#### 1. `QUICK_START.md`
- 60-second getting started guide
- Key commands and examples
- Common troubleshooting
- Integration patterns

#### 2. `AUTOMATED_FIX_RUNNER_README.md`
- Complete detailed documentation
- Full API reference for each script
- Advanced usage patterns
- Best practices and safety features
- Workflow examples

---

## Supported Issues and Fixes

The system recognizes and can fix:

| Issue | Pattern Key | Auto-Fix Available |
|-------|-------------|-------------------|
| Kafka CRD conflicts | `kafka_crd` | ✓ |
| Nexus storage space | `nexus_space` | ✓ |
| Spire pod initialization | `spire_pod` | ✓ |
| Spire PostgreSQL | `spire_postgres` | ✓ |
| PostgreSQL health | `postgres_health` | ✓ |
| Ceph cluster issues | `ceph_health` | ✓ |
| MetalLB IP allocation | `metallb_ip` | ✓ |
| HSM duplicate events | `hsm_events` | ✓ |
| Switch admin password | `switch_admin` | ✓ |
| Certificate expiration | `certificate` | ✓ |
| CNI migration (Weave→Cilium) | `cni_migration` | ✓ |
| BSS Cilium metadata | `bss_metadata` | ✓ |
| LDMS configuration | `ldms_config` | ✓ |

---

## Architecture

### Data Flow

```
PRE-UPGRADE LOGS
    ↓
    ├─→ [log_parser_workarounds.sh]
    │   ├─ Pattern matching (13 known issues)
    │   ├─ Reference extraction
    │   └─ Output: issues.workarounds.json
    │
    ├─→ [github_docs_searcher.sh]
    │   ├─ GitHub API search
    │   ├─ Document fetching
    │   ├─ Command extraction
    │   └─ Output: fixes.json
    │
    └─→ [csm_automated_fix_runner.sh]
        ├─ Display formatted issues
        ├─ Execute or prompt for fixes
        ├─ Log all operations
        └─ Output:
           ├─ Execution log
           ├─ Report
           └─ Exit code
```

### Processing Pipeline

1. **Parsing Phase** (log_parser_workarounds.sh)
   - Regex-based issue detection
   - Reference mapping
   - JSON serialization

2. **Search Phase** (github_docs_searcher.sh)
   - GitHub API calls
   - Base64 decoding
   - Command extraction with regex
   - Deduplication

3. **Execution Phase** (csm_automated_fix_runner.sh)
   - Prerequisite validation
   - Interactive or automatic mode
   - Safety checking (destructive commands)
   - Logging and reporting

---

## Safety Features

### 1. **Dry-Run Mode (Default)**
- All scripts enable dry-run by default
- No changes made to systems without explicit `-x` flag
- Safe preview of all operations

### 2. **Destructive Command Detection**
Commands with these keywords require extra confirmation:
- `delete`
- `remove`
- `rm -rf`
- `drop`
- `truncate`
- `uninstall`

### 3. **Comprehensive Logging**
All executed commands logged to:
```
/var/log/csm-fixes/fix_execution_YYYYMMDD_HHMMSS.log
```

### 4. **Prerequisites Validation**
- Checks for required commands (jq, curl, kubectl)
- Verifies Kubernetes cluster connectivity
- Validates GitHub API access
- Reports missing dependencies with suggestions

### 5. **Error Handling**
- Graceful handling of API rate limits
- Missing documentation doesn't block execution
- Failed fixes don't stop subsequent operations
- Detailed error messages for troubleshooting

---

## Usage Examples

### Example 1: Review Pre-Upgrade Issues (No Changes)
```bash
# Generate logs from your CSM system
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade_20260217.log

# Review what could be fixed (dry-run, safe)
./csm_automated_fix_runner.sh -l pre_upgrade_20260217.log

# Output shows:
# - Failed checks with suggested fixes
# - Links to documentation
# - Commands that would be run
# - All without making any changes
```

### Example 2: Interactive Fix Application
```bash
# Apply fixes with manual confirmation for each
./csm_automated_fix_runner.sh -l pre_upgrade.log -x

# For each issue, you'll see:
# [Issue details]
# Suggested Fixes:
#   [1] kubectl command...
#   [2] helm command...
# Apply these fixes? (y/n/skip):
```

### Example 3: Fully Automated Upgrade Preparation
```bash
# Set GitHub token for better API access (optional)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Run complete automation pipeline
./csm_automated_fix_runner.sh \
    -l pre_upgrade.log \
    -x \
    -a \
    -o /upgrade/staging \
    -v

# Check results
cat /upgrade/staging/csm_fix_report_*.md
tail -f /var/log/csm-fixes/fix_execution_*.log
```

### Example 4: Test Without Real Logs
```bash
# Generate sample test data
./test_and_examples.sh test

# Try the workflow with samples
./csm_automated_fix_runner.sh \
    -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log \
    -v

# No real infrastructure needed - perfect for testing
```

---

## Installation & Setup

### 1. Prerequisites
```bash
# Required on all systems
- bash 4.0+
- jq
- curl

# Optional (for full functionality)
- kubectl
- helm
- cray CLI
- GitHub personal access token
```

### 2. Installation
```bash
# Scripts are in cpv/scripts/ - make executable
chmod +x cpv/scripts/*.sh

# Optional: Add to PATH for easy access
export PATH="$PATH:/Users/keshavvarshney/Desktop/goLang/cpv/scripts"
```

### 3. Setup
```bash
# Create log directory (scripts will auto-create but can pre-create)
mkdir -p /var/log/csm-fixes

# Optional: Set GitHub token for better API access
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

---

## Output Examples

### Dry-Run Mode Output
```
[INFO] CSM Automated Fix Runner started
[INFO] Validating prerequisites...
[SUCCESS] Prerequisites validated

[Step 1/3] Parsing pre-upgrade check logs...
[SUCCESS] Logs parsed: issues_20260217_120000.workarounds.json

[Step 2/3] Searching GitHub docs-csm for workarounds...
[SUCCESS] GitHub search completed: fixes_20260217_120000.json

[Step 3/3] Processing extracted fixes...
[INFO] Found 5 issues with potential fixes

═══════════════════════════════════════════════════
Issue 1/5
  Type: FAIL
  Check: Checking for Kafka CRD issues
  Message: Kafka CRD conflict detected
  ✓ Documentation found
  References:
    - https://github.com/Cray-HPE/docs-csm/blob/master/troubleshooting/...

  Suggested Fixes:
    [1] bash /usr/share/doc/csm/troubleshooting/scripts/kafka_crd_fix.sh
    [2] kubectl rollout restart -n services deployment/cray-kafka-operator

  [DRY-RUN] Not executing fixes (use -x to enable execution)

[SUCCESS] Fix processing complete
[INFO] Applied: 0 | Skipped: 5
[SUCCESS] Report generated: csm_fix_report_20260217_120000.md
```

### Files Generated
```
/tmp/csm-analysis/
├── issues_20260217_120000.workarounds.json
├── fixes_20260217_120000.json
├── csm_fix_report_20260217_120000.md
└── /var/log/csm-fixes/
    └── fix_execution_20260217_120000.log
```

---

## Key Features

✅ **Fully Automated** - Single command to identify and fix issues  
✅ **Safe by Default** - Dry-run mode enabled, no changes without `-x`  
✅ **Well Documented** - Extensive README, quick start, and examples  
✅ **Extensible** - Easy to add new issue patterns and fixes  
✅ **Production Ready** - Error handling, logging, validation  
✅ **No Custom Logic** - Searches GitHub for actual workarounds  
✅ **Interactive & Automated** - Choose mode that fits your workflow  
✅ **Full Audit Trail** - All operations logged  

---

## Next Steps

### Quick Testing
```bash
# Generate sample data and try the workflow
./test_and_examples.sh test
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log
```

### First Real Use
```bash
# 1. Generate your pre-upgrade logs
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log

# 2. Review in dry-run mode (safe)
./csm_automated_fix_runner.sh -l pre_upgrade.log

# 3. When satisfied, apply fixes interactively
./csm_automated_fix_runner.sh -l pre_upgrade.log -x

# 4. Or auto-apply if confident
./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a
```

### Advanced Usage
- Integrate with upgrade pipelines
- Add custom issue patterns
- Create CI/CD hooks
- Generate compliance reports

---

## Support & Documentation

| Document | Purpose |
|----------|---------|
| [QUICK_START.md](QUICK_START.md) | 60-second getting started |
| [AUTOMATED_FIX_RUNNER_README.md](AUTOMATED_FIX_RUNNER_README.md) | Complete reference guide |
| `test_and_examples.sh docs` | Built-in documentation |
| `/var/log/csm-fixes/` | Execution logs and details |

---

## Summary

You now have a **production-ready automation system** that:

1. ✓ **Parses** pre-upgrade logs intelligently
2. ✓ **Searches** GitHub for real workarounds
3. ✓ **Extracts** specific fix commands
4. ✓ **Safely executes** with multiple confirmation levels
5. ✓ **Logs everything** for audit trails
6. ✓ **Handles errors** gracefully
7. ✓ **Documents** all operations

All with **zero modifications to your existing pre_upgrade_new_checks.sh** - the system works alongside it as a post-processing automation layer.
