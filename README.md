# CPV - Cray Pre-Upgrade Validation

A comprehensive system health check tool for validating readiness before CSM (Cray System Management) upgrades.

## 📋 What is This?

CPV is a collection of pre-upgrade validation scripts designed to check your system for potential issues **before** you upgrade your Cray cluster. Think of it as a "pre-flight checklist" for your system upgrade - it scans your system, identifies problems, logs them, and gives you a detailed report so you know what needs to be fixed before upgrading.

**Key Point:** These scripts are **read-only** - they don't change anything on your system, they just inspect and report.

---

## 🚀 Quick Start Guide

### Step 1: Clone the Repository to Your Local Machine

Open your terminal and run:

```bash
git clone https://github.com/keshav-06-hpe/cpv.git
```

Or if you prefer SSH:

```bash
git clone git@github.com:keshav-06-hpe/cpv.git
```

Then navigate into the folder:

```bash
cd cpv
```

### Step 2: Understand the Scripts

This repository contains two main scripts in the `scripts/` folder:

- **`pre_upgrade_checks-required.sh`** - **RUN THIS FIRST!**
  - Performs critical health checks required before upgrade
  - Checks for known issues that could block your upgrade
  - Takes ~15-20 minutes to run
  - **Must pass** before proceeding with upgrade

- **`pre_upgrade_checks-optional.sh`** - **RUN THIS SECOND**
  - Performs additional deep diagnostic checks
  - Helps identify non-critical issues and system information
  - Takes ~1-2 minutes to run
  - Recommended but not mandatory

### Step 3: Set Up Switch Admin Password

Before running the required checks, you need to provide the switch admin password. This is used for accessing network switch information during validation.

**Run this command FIRST:**

```bash
read -r -s -p "Switch admin password: " SW_ADMIN_PASSWORD

export SW_ADMIN_PASSWORD
```

**What this does:**
- `-r` = Don't interpret backslashes
- `-s` = Silent mode (password won't be displayed as you type)
- `-p` = Prompts you with the message "Switch admin password: "
- `export` = Makes the password available to the scripts

The prompt will wait for you to type your password and press Enter. Your typing won't be visible (for security) - that's normal!

**Example:**
```
$ read -r -s -p "Switch admin password: " SW_ADMIN_PASSWORD
Switch admin password: [you type here but nothing shows]
$ export SW_ADMIN_PASSWORD
$ 
```

### Step 4: Run the Scripts

**On your Cray cluster system**, run the scripts with elevated permissions:


```bash
# Run the required checks first (uses the password you just exported)
bash scripts/pre_upgrade_checks-required.sh

# Then run the optional checks
bash scripts/pre_upgrade_checks-optional.sh
```

> **⚠️ Important:** When running `pre_upgrade_checks-required.sh`, you will be prompted to provide input for the **test_bican_internal** test. Please have the necessary information ready when the script asks for it.

---

## 📊 What Happens When You Run It?

### Before It Starts

1. Scripts create a timestamped folder to store all results
2. Sets up the logging structure
3. Counts total checks to run

### While It's Running

1. Each check is executed one by one
2. Results are printed to your terminal in **real-time** with color coding:
   - 🟢 **GREEN** = Check passed
   - 🔴 **RED** = Check failed (problem found)
   - 🟡 **YELLOW** = Check warning (something to watch)
   - 🔵 **BLUE** = Information message

3. All output is also saved to log files

### When It Completes

1. Summary report shows:
   - Total checks run
   - How many passed
   - How many failed
   - How many warnings
   - Which specific checks failed (if any)

2. Detailed logs saved for your records

---

## 📁 Where Are the Logs Stored?

### Log Directory Location

```
/etc/cray/upgrade/csm/pre-checks/
```

This is where **ALL** logs and results are stored.


### Understanding Log Timestamps

Each time you run the script, a new folder is created with today's date and time:
- `20250219_143022` means Feb 19, 2025 at 14:30:22 (2:30 PM)

This way, you can keep multiple runs for comparison.

---

## 📖 How to Read the Logs

### Quick Summary

After the script runs, look for the main output at the end:

```
========================================
SUMMARY REPORT
========================================
Total Checks:     50
Passed:           48
Failed:            1
Warnings:          1

Failed Checks:
  - CHECK_015: Kernel Version Too Old

Warning Checks:
  - CHECK_023: Disk Space Below 20%
```

> **💡 Note about Optional Script:** If you run the optional checks script and notice that the total checks don't sum up perfectly, don't worry! All check files (including skipped or non-critical checks) can be viewed in the `/etc/cray/upgrade/csm/pre-checks/checks_<timestamp>` directory. This is normal behavior and simply means some checks were conditional or grouped.

### Detailed Check Logs

For each failed check, go to:
```
/etc/cray/upgrade/csm/pre-checks/checks_[TIMESTAMP]/failed_warnings/
```

Open the file to see:
- What was checked
- What was expected
- What was actually found
- Suggested fix

**Example file name:** `[FAIL]_CHECK_015_Kernel_Version.log`

> **🔍 Important Note for pre_upgrade_checks-required.sh:** When you receive the collective logs at the end, check the files in the `failed_warnings/` directory carefully. Not all issues listed there are necessarily **actual failures**. Some may be **false positives** or informational items. Always review the details in each log file to understand:
> - Is this a real problem that needs fixing?
> - Or is this just a warning/informational flag that can be safely ignored?
> - The log will contain context to help you determine the severity

### View Logs in Terminal

```bash
# View the main summary
cat /etc/cray/upgrade/csm/pre-checks/pre_upgrade_checks_*.log

# View a specific failed check
cat /etc/cray/upgrade/csm/pre-checks/checks_*/failed_warnings/[FAIL]_*.log

# View all passed checks
ls /etc/cray/upgrade/csm/pre-checks/checks_*/passed/

# Count total passed/failed
ls /etc/cray/upgrade/csm/pre-checks/checks_*/passed/ | wc -l
ls /etc/cray/upgrade/csm/pre-checks/checks_*/failed_warnings/ | wc -l
```

---

## 🔍 Sample Output

### What You'll See in Terminal

```
========================================
CSM Pre-Upgrade Health Checks
========================================

[CHECK 1/50] DNS Resolution
[RUN] nslookup google.com
[PASS] DNS Resolution

[CHECK 2/50] Network Connectivity
[RUN] ping -c 1 8.8.8.8
[PASS] Network Connectivity

[CHECK 15/50] Kernel Version
[RUN] uname -r
[FAIL] Kernel Version Too Old - Required: 5.15+ Found: 5.10
⚠️  This may impact upgrade

========================================
SUMMARY REPORT
========================================
Total Checks:     50
Passed:           48
Failed:            1
Warnings:          1

❌ ACTION REQUIRED:
  1. Fix the 1 failed check before upgrading
  2. Review 1 warning for potential issues
```

---

## 🛠️ What Gets Checked?

### Required Checks (required.sh)

These are critical - upgrade will fail if these don't pass:

1. ✅ System disk space availability
2. ✅ Required services running
3. ✅ Network connectivity
4. ✅ DNS resolution
5. ✅ Kernel version compatibility
6. ✅ Memory availability
7. ✅ Necessary packages installed
8. ✅ Port availability
9. ✅ File system integrity
10. ... and many more critical checks

### Optional Checks (optional.sh)

These provide additional insights:

1. ℹ️ Current system configuration
2. ℹ️ Hardware information
3. ℹ️ Running process list
4. ℹ️ Open ports
5. ℹ️ System logs for errors
6. ℹ️ Known issue detection
7. ℹ️ Performance metrics
8. ... and detailed diagnostic data

---

## 📝 Typical Workflow

### Step-by-Step Process

```
1. Clone this repository
   └─ cd cpv

2. Copy scripts to your Cray system
   └─ scp scripts/*.sh your-cray-system:/tmp/

3. SSH into your Cray system
   └─ ssh your-cray-system

4. Set the switch admin password
   └─ read -r -s -p "Switch admin password: " SW_ADMIN_PASSWORD
   └─ export SW_ADMIN_PASSWORD

5. Run required checks
   └─ sudo bash /tmp/pre_upgrade_checks-required.sh
   └─ Review output for any failures

5. If no failures, run optional checks
   └─ bash /tmp/pre_upgrade_checks-optional.sh
   └─ Review detailed results

6. Check the logs directory
   └─ ls /etc/cray/upgrade/csm/pre-checks/
   └─ Review any failed checks

7. Fix any issues found
   └─ Follow suggestions from the logs

8. Re-run if you fixed something
   └─ sudo bash /tmp/pre_upgrade_checks-required.sh
   └─ Verify everything now passes

9. Proceed with actual upgrade
   └─ You're good to go!
```

---

## 🚨 Troubleshooting

### "Permission Denied" Error

**Problem:** You didn't use `sudo`

**Solution:**
```bash
sudo bash scripts/pre_upgrade_checks-required.sh
```

### "Command not found" Error

**Problem:** The script path is incorrect

**Solution:**
```bash
# Make sure you're in the cpv directory
cd /path/to/cpv

# Then run
sudo bash scripts/pre_upgrade_checks-required.sh
```

### "Can't access log directory" Error

**Problem:** The log directory doesn't exist or you don't have permissions

**Solution:**
```bash
# Create the directory
sudo mkdir -p /etc/cray/upgrade/csm/pre-checks

# Give yourself permission
sudo chmod 755 /etc/cray/upgrade/csm/pre-checks

# Try running the script again
sudo bash scripts/pre_upgrade_checks-required.sh
```

### How Do I Know If It's Still Running?

The script can take 5-30 minutes depending on checks. You'll know it's working if:
- Terminal shows colored output
- New log files are being created (check: `ls /etc/cray/upgrade/csm/pre-checks/checks_*/`)
- You can see timestamps changing

### Script Crashed or Got Interrupted?

No problem! Just run it again:
```bash
sudo bash scripts/pre_upgrade_checks-required.sh
```

Each run creates a **new** timestamped folder, so old results aren't lost.
---