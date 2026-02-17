# 🚀 CSM Automated Fix Runner - START HERE

Welcome! This directory contains a complete automation system for CSM pre-upgrade log analysis and fix execution.

## ⚡ Quick Start (30 seconds)

### 1. Run the main script:
```bash
cd /Users/keshavvarshney/Desktop/goLang/cpv/automated-fix-runner
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log
```

### 2. Review the output (no changes made in dry-run mode)

### 3. When ready to apply fixes:
```bash
./csm_automated_fix_runner.sh -l /path/to/pre_upgrade.log -x
```

---

## 📚 Documentation Files (Pick Your Path)

### For the Impatient ⚡ (5 minutes)
Read: [QUICK_START.md](QUICK_START.md)
- 60-second overview
- Common commands
- Troubleshooting quick ref

### For Getting Started 📖 (10 minutes)
Read: [README_COMPLETE_SOLUTION.md](README_COMPLETE_SOLUTION.md)
- Complete overview
- All features explained
- Safety mechanisms
- Three operating modes

### For Production Use 🏢 (30 minutes)
Read: [AUTOMATED_FIX_RUNNER_README.md](AUTOMATED_FIX_RUNNER_README.md)
- Full API reference
- All options and flags
- Advanced usage
- Complete troubleshooting guide

### For Technical Understanding 🏗️ (20 minutes)
Read: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
- Architecture overview
- Data flow diagrams
- Design decisions
- All 13+ supported issues

### For Navigation 🗂️ (Quick reference)
Read: [INDEX.md](INDEX.md) or [MANIFEST.md](MANIFEST.md)
- File index
- Quick reference
- Learning paths

---

## 📦 What's Included

### Scripts (4)
- **csm_automated_fix_runner.sh** - Main script (run this!)
- **log_parser_workarounds.sh** - Parse logs
- **github_docs_searcher.sh** - Search GitHub for fixes
- **test_and_examples.sh** - Generate test data

### Documentation (6)
- **README_COMPLETE_SOLUTION.md** - Overview & getting started
- **QUICK_START.md** - Quick reference
- **AUTOMATED_FIX_RUNNER_README.md** - Full documentation
- **IMPLEMENTATION_SUMMARY.md** - Technical details
- **INDEX.md** - Navigation guide
- **MANIFEST.md** - Package contents

---

## 🎯 What This System Does

```
Pre-Upgrade Logs
    ↓
[Parses Issues] ← Recognizes 13+ issue patterns
    ↓
[Searches GitHub] ← Finds workarounds from docs-csm
    ↓
[Extracts Fixes] ← Identifies specific commands
    ↓
[Executes Safely] ← Applies fixes with confirmation
    ↓
[Logs Everything] ← Full audit trail
```

---

## ⚡ Three Operating Modes

### Mode 1: Review (Dry-Run) - DEFAULT ✅
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log
```
Shows what would be fixed. **No changes made.** Safe to explore.

### Mode 2: Interactive (-x) 🔄
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -x
```
Prompts before each fix. You approve or skip.

### Mode 3: Auto-Apply (-x -a) ⚙️
```bash
./csm_automated_fix_runner.sh -l pre_upgrade.log -x -a
```
Applies all fixes automatically (destructive commands still need confirmation).

---

## 🧪 Test Without Real Logs

```bash
./test_and_examples.sh test
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log
```

Perfect for trying it out without real infrastructure!

---

## ✨ Key Features

✅ **Safe by default** - Dry-run mode prevents accidents  
✅ **Single command** - One script does everything  
✅ **GitHub integrated** - Real workarounds from docs-csm  
✅ **13+ issue patterns** - Kafka, Nexus, Spire, PostgreSQL, etc.  
✅ **Full logging** - Audit trail at `/var/log/csm-fixes/`  
✅ **Production ready** - Error handling, validation, recovery  
✅ **Well documented** - 40+ KB of guides and examples  

---

## 🛡️ Safety Features

- ✅ Dry-run enabled by default (no `-x` = no changes)
- ✅ Destructive commands require confirmation
- ✅ Full execution logging
- ✅ Prerequisite validation
- ✅ Kubernetes cluster checks
- ✅ Error recovery
- ✅ Clear error messages

---

## 📍 Directory Structure

```
automated-fix-runner/
├── 🚀 SCRIPTS
│   ├── csm_automated_fix_runner.sh         ← Main script
│   ├── log_parser_workarounds.sh
│   ├── github_docs_searcher.sh
│   └── test_and_examples.sh
│
└── 📚 DOCUMENTATION
    ├── START_HERE.md                       ← You are here
    ├── QUICK_START.md                      ← 5 min read
    ├── README_COMPLETE_SOLUTION.md         ← 10 min read
    ├── AUTOMATED_FIX_RUNNER_README.md      ← 30 min read
    ├── IMPLEMENTATION_SUMMARY.md           ← Technical
    ├── INDEX.md                            ← Navigation
    └── MANIFEST.md                         ← Package info
```

---

## 📋 Supported Issues

| # | Issue | Status |
|-|-|-|
| 1 | Kafka CRD conflicts | ✅ |
| 2 | Nexus storage | ✅ |
| 3 | Spire pods | ✅ |
| 4 | PostgreSQL health | ✅ |
| 5 | Ceph cluster | ✅ |
| 6 | MetalLB IPs | ✅ |
| 7 | HSM duplicates | ✅ |
| 8 | Certificates | ✅ |
| 9 | CNI migration | ✅ |
| 10 | LDMS config | ✅ |
| 11+ | More... | ✅ |

---

## ❓ Getting Help

| Need | Do This |
|------|---------|
| Quick overview | Read QUICK_START.md |
| Complete guide | Read AUTOMATED_FIX_RUNNER_README.md |
| Technical details | Read IMPLEMENTATION_SUMMARY.md |
| See it work | Run `./test_and_examples.sh test` |
| Help text | Run `./csm_automated_fix_runner.sh -h` |
| Check logs | `tail -f /var/log/csm-fixes/fix_execution_*.log` |

---

## 🚀 Next Steps

### Right Now (2 minutes)
```bash
cd /Users/keshavvarshney/Desktop/goLang/cpv/automated-fix-runner
./test_and_examples.sh test
./csm_automated_fix_runner.sh -l /tmp/csm-fix-runner-test/sample_pre_upgrade.log
```

### With Real Logs (When ready)
```bash
# Generate pre-upgrade logs
/opt/cray/csm/scripts/pre_upgrade_new_checks.sh > pre_upgrade.log

# Review (safe)
./csm_automated_fix_runner.sh -l pre_upgrade.log

# Apply (when satisfied)
./csm_automated_fix_runner.sh -l pre_upgrade.log -x
```

### For Deep Dive (Read documentation)
1. README_COMPLETE_SOLUTION.md (10 min)
2. QUICK_START.md (5 min)
3. AUTOMATED_FIX_RUNNER_README.md (30 min)

---

## ✅ Everything is Ready

All scripts are:
- ✅ Executable
- ✅ Well-documented
- ✅ Production-ready
- ✅ Tested

**Pick a documentation file above and get started!** 🎉

---

**Last updated:** February 17, 2026  
**Status:** Production Ready  
**Version:** 1.0
