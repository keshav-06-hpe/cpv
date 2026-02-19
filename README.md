# CPV - Cray Pre-Upgrade Validation

A comprehensive system health check tool for validating readiness before CSM (Cray System Management) upgrades.

## 📋 Overview

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

### Step 2: Tests Covered

This repository contains two main scripts in the `scripts/` folder:

#### **`pre_upgrade_checks-required.sh`** - **RUN THIS FIRST!**

**Purpose:** Performs critical health checks required before upgrade - Must pass before proceeding
**Time:** ~15-20 minutes

**Test Cases Covered:**
1. ✅ HSM Discovery Status Test (`hsm_discovery_status_test`)
2. ✅ HMS Discovery Verification (`verify_hsm_discovery`)
3. ✅ Hardware Checks (`run_hardware_checks`)
4. ✅ BOS v1 Session Logs (`bos_v1_session_logs`)
5. ✅ CMSdev Test All (`cmsdev_test_all`)
6. ✅ NCN Gateway Test (`ncn_gateway_test`)
7. ✅ BICAN Internal Test (`test_bican_internal`) - **Requires user input**
8. ✅ Slingshot Fabric Manager (`slingshot_fmn_show_status`)
9. ✅ Slingshot Link Debug Fabric (`slingshot_linkdbg_fabric`)
10. ✅ Slingshot Link Debug Edge (`slingshot_linkdbg_edge`)
11. ✅ Slingshot Show Flaps (`slingshot_show_flaps`)
12. ✅ Ceph Status (`ceph_s`)
13. ✅ Ceph OSD Performance (`ceph_osd_perf`)
14. ✅ Ceph Orchestration Status (`ceph_orch_ls`, `ceph_orch_ps`)
15. ✅ Ceph OSD Tree (`ceph_osd_tree`)
16. ✅ HMS Discovery Cronjob (`kubectl_get_cronjobs_hms_discovery`)
17. ✅ Kubernetes Pod CPU/Memory Usage
18. ✅ SAT Status Checks (ChassisBMC, NodeBMC, ComputeModule, HSNBoard, NodeEnclosure, Chassis, Node, RouterBMC, RouterModule)
19. ✅ SAT Inventory (`sat_showrev`, `sat_firmware`, `sat_hwinv`, `sat_hwmatch`, `sat_slscheck`)
20. ✅ SAT Compute Node Status
21. ✅ SLS Dumpstate (`cray_sls_dumpstate`)
22. ✅ And many more critical system checks

#### **`pre_upgrade_checks-optional.sh`** - **RUN THIS SECOND**

**Purpose:** Performs additional deep diagnostic checks and system information collection
**Time:** ~1-2 minutes
**Note:** Recommended but not mandatory

**Test Cases Covered:**
1. ℹ️ Crash Dump Inventory (`pdsh_ls_var_crash`)
2. ℹ️ Cassini NIC Firmware Query (`pdsh_slingshot_firmware_query`)
3. ℹ️ SDU Collections Status (`pdsh_sdu_list`, `pdsh_sdu_collection_local`, `pdsh_sdu_collection_mount`)
4. ℹ️ SDU/RDA Configuration (`sdu_conf`, `rda_conf`, `rda_acl`, `rda_hosts`)
5. ℹ️ Namespace Resource Limits (`namespace_resource_limits`)
6. ℹ️ Pod Resource Limits (`pod_resource_limits`)
7. ℹ️ OOM Events Detection (`kubectl_oom_events`)
8. ℹ️ Kubernetes Node Description (`kubectl_describe_nodes`)
9. ℹ️ Kubernetes Allocated Resources (`kubectl_allocated_resources`)
10. ℹ️ Kubernetes Node Conditions (`kubectl_node_conditions`)
11. ℹ️ SMA AIOPS Configuration (`sma_aiops_config`)
12. ℹ️ CM Health and Alert Status (Multiple checks)
13. ℹ️ BOS/CFS Options (`cray_bos_v2_options`, `cray_cfs_options`, `cray_cfs_v3_options`)
14. ℹ️ CFS Configuration and Logs (`cfs_default_ansible_cfg`, `cfs_sorted_pods`, `cfs_successful_jobs`, `cfs_batcher_logs`)
15. ℹ️ Nexus Backup and Space Usage (`nexus_pvc`, `nexus_df`, `nexus_space_usage`)
16. ℹ️ etcd Health Check (`etcd_member_list`, `etcd_endpoint_health`)
17. ℹ️ Certificate Expiration Checks (SPIRE, Etcd, SMA, OAuth2, etc.)
18. ℹ️ Weave Network Status (`weave_status`)
19. ℹ️ Node Filesystem Usage (`df_containerd`, `df_kubelet`, `df_s3fs_cache`, `df_root`)
20. ℹ️ CriCTL Pod Status (`crictl_pods_notready`)
21. ℹ️ SPIRE Entry Counts (`spire_entry_count`, `spire_entry_count_list`)
22. ℹ️ NCN Health Checks (`ncnHealthChecks_all`, `ncnHealthChecks_ncn_uptimes`, `ncnHealthChecks_node_resource_consumption`, `ncnHealthChecks_pods_not_running`)
23. ℹ️ PostgreSQL Health Checks (`ncnPostgresHealthChecks`, `ncn_postgres_tests`)
24. ℹ️ Kubernetes Combined Health Check (`ncn_k8s_combined_healthcheck`)
25. ℹ️ Cluster-wide Pod Inventory (`kubectl_get_pods_wide`)

### Step 3: Set Up Switch Admin Password

Before running the required checks, you need to provide the switch admin password. This is used for accessing network switch information during validation.

**Run this command FIRST:**

```bash
read -r -s -p "Switch admin password: " SW_ADMIN_PASSWORD
export SW_ADMIN_PASSWORD
```

The prompt will wait for you to type your password and press Enter. Your typing won't be visible (for security) - that's normal!

**Example:**
```
$ read -r -s -p "Switch admin password: " SW_ADMIN_PASSWORD
Switch admin password: [you type here but nothing shows]
$ export SW_ADMIN_PASSWORD
$ 
```

### Step 4: Run the Scripts

**On your Cray cluster system**, ensure the scripts have executable permission and run them:

```bash
# Make scripts executable (if needed)
chmod +x scripts/*.sh
```

Then run:

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
/opt/cray/tests/cpv/
```

This is where **ALL** logs and results are stored.


### Understanding Log Timestamps

Each time you run the script, a new folder is created with today's date and time:
- `20250219_143022` means Feb 19, 2025 at 14:30:22 (2:30 PM)
- For required script: `checks_<timestamp>/`
- For optional script: `checks_optional_<timestamp>/`

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

> **💡 Note about Optional Script:** If you run the optional checks script and notice that the total checks don't sum up perfectly, don't worry! All check files (including skipped or non-critical checks) can be viewed in the `/opt/cray/tests/cpv/checks_optional_<timestamp>` directory. This is normal behavior and simply means some checks were conditional or grouped.

### Detailed Check Logs

For each failed check, go to:
```
/opt/cray/tests/cpv/checks_required_[TIMESTAMP]/failed_warnings/
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
cat /opt/cray/tests/cpv/pre_upgrade_checks_*.log

# View a specific failed check
cat /opt/cray/tests/cpv/checks_required_*/failed_warnings/[FAIL]_*.log

# View all passed checks
ls /opt/cray/tests/cpv/checks_required_*/passed/

# Count total passed/failed
ls /opt/cray/tests/cpv/checks_required_*/passed/ | wc -l
ls /opt/cray/tests/cpv/checks_required_*/failed_warnings/ | wc -l
```

---

## Preparing Logs for Analysis

Once you've collected the logs and are ready to proceed with analysis, you can compress the log folder for transfer and analysis.

### Step 1: Compress the Log Folder

Navigate to the log directory and create a compressed archive for the folders(both scripts outputs):

**Using TAR (Recommended for Linux/Mac):**

```bash
# Create a tar.gz archive of the logs
cd /opt/cray/tests/cpv/
tar -czf checks_required_$(date +%Y%m%d_%H%M%S).tar.gz checks_required_<timestamp>/
tar -czf checks_optional_$(date +%Y%m%d_%H%M%S).tar.gz checks_optional_<timestamp>/

```

**Using ZIP (Works across all systems):**

```bash
# Create a zip archive of the logs
cd /opt/cray/tests/cpv/
zip -r checks_required_$(date +%Y%m%d_%H%M%S).zip checks_required_<timestamp>/
zip -r checks_optional_$(date +%Y%m%d_%H%M%S).zip checks_optional_<timestamp>/

```


### Step 2: Transfer the Archive to Your Local Machine

```bash
# Download from Cray system to your local machine
scp your-username@your-cray-system:/opt/cray/tests/cpv/checks_required_*.tar.gz ./
scp your-username@your-cray-system:/opt/cray/tests/cpv/checks_optional_*.tar.gz ./

# Or for zip
scp your-username@your-cray-system:/opt/cray/tests/cpv/checks_required_*.zip ./
scp your-username@your-cray-system:/opt/cray/tests/cpv/checks_optional_*.zip ./
```

### Step 4: Extract on Your Local Machine (if needed)

```bash
# For tar.gz
tar -xzf checks_*.tar.gz

# For zip
unzip checks_*.zip
```

### Step 5: Use for Analysis

- Use the Similarity Search Engine for further proceedings

---

## Sample Output

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
   └─ bash /tmp/pre_upgrade_checks-required.sh
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
sudo mkdir -p /opt/cray/tests/cpv

# Give yourself permission
sudo chmod 755 /opt/cray/tests/cpv

# Try running the script again
bash scripts/pre_upgrade_checks-required.sh
```

### How Do I Know If It's Still Running?

The script can take 5-30 minutes depending on checks. You'll know it's working if:
- Terminal shows colored output
- New log files are being created (check: `ls /opt/cray/tests/cpv/checks_*/`)
- You can see timestamps changing

### Script Crashed or Got Interrupted?

No problem! Just run it again:
```bash
bash scripts/pre_upgrade_checks-required.sh
```

Each run creates a **new** timestamped folder, so old results aren't lost.

---