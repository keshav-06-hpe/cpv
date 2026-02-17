# CSM Automated Fix Runner - Complete Package Index

## 📦 Package Contents

This package provides **complete automation for CSM pre-upgrade log analysis, GitHub workaround searching, and safe fix execution**.

---

## 📋 Script Files

### Main Scripts (Executable)

#### 1. **csm_automated_fix_runner.sh** ⭐ START HERE
- **Size:** ~13 KB
- **Purpose:** Main orchestration script - runs the complete pipeline
- **What it does:**
  - Parses logs to identify issues
  - Searches GitHub docs for workarounds
  - Displays fixes in interactive format
  - Optionally executes fixes safely
- **Modes:** Dry-run (default), Interactive (-x), Auto-apply (-x -a)
- **Usage:**
  ```bash
  ./csm_automated_fix_runner.sh -l pre_upgrade.log        # Review
  ./csm_automated_fix_runner.sh -l pre_upgrade.log -x     # Interactive
  ./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a  # Auto
  ```

#### 2. **log_parser_workarounds.sh**
- **Size:** ~9.3 KB
- **Purpose:** Parse logs and extract issues (called by main script)
- **Features:**
  - Pattern matching for 13 known issue types
  - Reference extraction
  - JSON output
- **Manual usage:**
  ```bash
  ./log_parser_workarounds.sh -l pre_upgrade.log -o issues.json
  ```

#### 3. **github_docs_searcher.sh**
- **Size:** ~9.2 KB
- **Purpose:** Search GitHub for fixes (called by main script)
- **Features:**
  - GitHub API integration
  - Document fetching and parsing
  - Command extraction
- **Manual usage:**
  ```bash
  ./github_docs_searcher.sh -i issues.json -o fixes.json
  ```

#### 4. **test_and_examples.sh**
- **Size:** ~17 KB
- **Purpose:** Generate test data and examples
- **Subcommands:**
  ```bash
  ./test_and_examples.sh test  # Generate sample data
  ./test_and_examples.sh docs  # Show documentation
  ```

---

## 📚 Documentation Files

### Quick Reference

#### **QUICK_START.md** ⭐ READ FIRST
- 60-second getting started guide
- Key commands with examples
- Common tasks and troubleshooting
- ~200 lines, 5-10 minute read

#### **AUTOMATED_FIX_RUNNER_README.md**
- Complete detailed documentation
- Full API reference for each script
- Advanced usage patterns
- Component descriptions
- Troubleshooting guide
- ~500 lines, comprehensive reference

#### **IMPLEMENTATION_SUMMARY.md**
- Architecture overview
- What was created and why
- Data flow diagrams
- Supported issues table
- Safety features explained
- Usage examples
- ~400 lines, technical deep-dive

---

## 🚀 Quick Start

### 1. Generate Pre-Upgrade Logs
```bash
# Run this on your CSM system to generate logs
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log
```

### 2. Run the Main Script
```bash
# Navigate to scripts directory
cd cpv/scripts

# Review what would be fixed (safe, no changes)
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log

# Or apply fixes interactively (prompts before each)
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log -x

# Or apply all fixes automatically
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log -x -a
```

### 3. Review Results
```bash
# Check the generated report
cat csm_fix_report_*.md

# View execution log
tail -f /var/log/csm-fixes/fix_execution_*.log
```

---

## 📊 What Gets Generated

### Output Files
| File | Contains |
|------|----------|
| `issues_*.workarounds.json` | Parsed issues from logs |
| `fixes_*.json` | Fixes extracted from GitHub |
| `csm_fix_report_*.md` | Summary report (markdown) |
| `/var/log/csm-fixes/*.log` | Detailed execution log |

### Example Output Directories
```
Current Directory/
├── issues_20260217_120000.workarounds.json
├── fixes_20260217_120000.json
├── csm_fix_report_20260217_120000.md

/var/log/csm-fixes/
└── fix_execution_20260217_120000.log
```

---

## 🔍 Supported Issues

The system recognizes and can fix:

| # | Issue | Pattern Key | Fix Available |
|---|-------|-------------|---------------|
| 1 | Kafka CRD conflicts | `kafka_crd` | ✓ |
| 2 | Nexus storage | `nexus_space` | ✓ |
| 3 | Spire pod issues | `spire_pod` | ✓ |
| 4 | PostgreSQL health | `postgres_health` | ✓ |
| 5 | Ceph cluster | `ceph_health` | ✓ |
| 6 | MetalLB IPs | `metallb_ip` | ✓ |
| 7 | HSM duplicates | `hsm_events` | ✓ |
| 8 | Certificates | `certificate` | ✓ |
| 9 | CNI migration | `cni_migration` | ✓ |
| 10 | BSS metadata | `bss_metadata` | ✓ |
| 11 | LDMS config | `ldms_config` | ✓ |
| 12 | Spire Postgres | `spire_postgres` | ✓ |
| 13 | Switch password | `switch_admin` | ✓ |

---

## ⚙️ System Requirements

### Required
- bash 4.0+
- jq (JSON parsing)
- curl (API calls)

### Optional (for full functionality)
- kubectl (Kubernetes operations)
- helm (Kubernetes package manager)
- cray CLI (CSM commands)
- GitHub personal access token (for better API rate limits)

### Installation
```bash
# macOS
brew install jq curl

# Ubuntu/Debian
apt-get install jq curl

# CentOS/RHEL
yum install jq curl
```

---

## 🛡️ Safety Features

### Dry-Run Mode (Default)
- **Enabled by default**
- Shows what fixes would apply
- No actual changes made
- Safe to review

### Interactive Mode (-x flag)
- Prompts before each fix
- You approve each operation
- Destructive commands require extra confirmation

### Auto-Apply Mode (-x -a)
- Applies all fixes automatically
- **Destructive commands still require confirmation**
- Full execution logging
- Designed for automated pipelines

### Protection Mechanisms
✅ All commands logged to `/var/log/csm-fixes/`  
✅ Kubernetes cluster validation  
✅ GitHub API rate limit handling  
✅ Prerequisite checking  
✅ Error recovery  

---

## 📖 Documentation Reading Guide

### For Quick Implementation (5 minutes)
1. Read: **QUICK_START.md** - Understand the 3 modes
2. Try: `./test_and_examples.sh test` - Generate sample data
3. Run: `./csm_automated_fix_runner.sh -l sample_log.txt` - See it work

### For Production Use (30 minutes)
1. Read: **QUICK_START.md** - Get overview
2. Read: **AUTOMATED_FIX_RUNNER_README.md** - Understand all options
3. Bookmark: **IMPLEMENTATION_SUMMARY.md** - Reference architecture
4. Plan: Integration with your upgrade process

### For Deep Understanding (60 minutes)
1. Read: All three documentation files
2. Study: Script structure and comments
3. Understand: Data flow and architecture
4. Customize: Add your own issue patterns

---

## 🔧 Common Operations

### Test Without Real Logs
```bash
./test_and_examples.sh test
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log
```

### Run with GitHub Token (Better API Access)
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./csm_automated_fix_runner.sh -l pre_upgrade.log
```

### Run in Verbose Mode (Debugging)
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -v -x
```

### Generate Just the Report
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -o /output/dir
cat /output/dir/csm_fix_report_*.md
```

### Show Documentation
```bash
./test_and_examples.sh docs
./csm_automated_fix_runner.sh -h
./github_docs_searcher.sh -h
./log_parser_workarounds.sh -h
```

---

## 🐛 Troubleshooting

### "jq command not found"
```bash
# Install jq
brew install jq        # macOS
apt-get install jq     # Ubuntu
yum install jq         # CentOS
```

### "GitHub API rate limit exceeded"
```bash
# Use a personal access token
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./csm_automated_fix_runner.sh -l pre_upgrade.log
```

### "Cannot connect to Kubernetes"
```bash
# Ensure you're on a machine with kubectl access, or
# Set KUBECONFIG to your cluster config
export KUBECONFIG=/path/to/kubeconfig
./csm_automated_fix_runner.sh -l pre_upgrade.log
```

### "Command execution failed"
```bash
# Check the detailed log
cat /var/log/csm-fixes/fix_execution_*.log

# Run in verbose mode for more details
./csm_automated_fix_runner.sh -l pre_upgrade.log -v -x

# Search for ERROR in logs
grep ERROR /var/log/csm-fixes/fix_execution_*.log
```

---

## 📝 File Structure

```
cpv/scripts/
├── csm_automated_fix_runner.sh       ← Main script (start here)
├── log_parser_workarounds.sh         ← Parse logs (called automatically)
├── github_docs_searcher.sh           ← Search GitHub (called automatically)
├── test_and_examples.sh              ← Generate test data
├── QUICK_START.md                    ← 60-second guide (read this first)
├── AUTOMATED_FIX_RUNNER_README.md    ← Complete reference
└── IMPLEMENTATION_SUMMARY.md         ← Architecture overview
```

---

## ✅ Workflow Summary

```
┌─────────────────────────────────────────┐
│  Generate Pre-Upgrade Check Logs        │
│  /opt/cray/csm/scripts/                 │
│  pre_upgrade_new_checks.sh              │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  Run Main Script (csm_automated_fix_    │
│  runner.sh -l pre_upgrade.log)          │
├─────────────────────────────────────────┤
│  ✓ Parse logs → issues.json             │
│  ✓ Search GitHub → fixes.json           │
│  ✓ Display formatted output             │
│  ✓ Ask/execute/auto fixes               │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  Review Outputs                         │
│  • csm_fix_report_*.md                  │
│  • /var/log/csm-fixes/*.log             │
└─────────────────────────────────────────┘
```

---

## 🎯 Key Features

✅ **Single Command** - One script handles everything  
✅ **Safe by Default** - Dry-run mode prevents accidents  
✅ **Fully Documented** - 1500+ lines of docs  
✅ **Flexible Modes** - Review, interactive, or auto  
✅ **GitHub Integration** - Real workarounds from docs-csm  
✅ **Production Ready** - Error handling, logging, validation  
✅ **No Modifications** - Works alongside existing scripts  
✅ **Extensible** - Easy to add custom patterns  
✅ **Comprehensive Logging** - Full audit trail  

---

## 📞 Support

| Need | Resource |
|------|----------|
| Quick start | [QUICK_START.md](QUICK_START.md) |
| Full reference | [AUTOMATED_FIX_RUNNER_README.md](AUTOMATED_FIX_RUNNER_README.md) |
| Architecture | [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) |
| Examples | `./test_and_examples.sh docs` |
| Help text | `./csm_automated_fix_runner.sh -h` |
| Logs | `/var/log/csm-fixes/fix_execution_*.log` |

---

## 🚀 Next Steps

### Option 1: Try It Now (5 minutes)
```bash
cd cpv/scripts
./test_and_examples.sh test
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log -v
```

### Option 2: Plan Production Use (30 minutes)
1. Read QUICK_START.md
2. Review AUTOMATED_FIX_RUNNER_README.md
3. Plan integration with your upgrade process
4. Set up GitHub token

### Option 3: Deep Dive (60+ minutes)
1. Study all documentation
2. Review script implementations
3. Understand data flow architecture
4. Customize for your environment

---

**You're all set! Start with `./csm_automated_fix_runner.sh -l <logfile>`**
