# Pre-Upgrade Check Script

## Overview
This script performs comprehensive pre-installation checks for the CSM upgrade from version 25.3.2 (1.6.2) to 25.9.0 (1.7.0). It validates the system against all known issues documented in the upgrade checklist.

## Features

### What It Checks

1. **CSM Core Issues**
   - Active IUF sessions that could block upgrade
   - Nexus storage space (warns if >80% full)
   - Kafka CRD configuration

2. **CSM Diags Issues**
   - Slurm AllowedRAMSpace configuration
   - Multi-tenancy installation conflicts
   - Current CSM Diags installation status

3. **Hardware Firmware Pack (HFP) Issues**
   - EX254n blade firmware versions
   - FAS loader status

4. **Slingshot Host Software (SHS) Issues**
   - SS10 hardware compatibility warnings
   - High-rank MPI job compatibility (>252 ppn)
   - CXI service configuration

5. **Slingshot Fabric Issues**
   - Certificate Manager keystore health
   - Filesystem space for certificate operations
   - Fabric backup status (Velero)

6. **System Monitoring Application (SMA) Issues**
   - Helm releases stuck in uninstalling state
   - OpenSearch pod health
   - Required Kafka topics
   - LDMS configuration compatibility

7. **User Services Software (USS) Issues**
   - PBS Professional version compatibility
   - Slurm version and configuration
   - cos-config-service removal check
   - NMD (Node Memory Dump) configuration
   - NVIDIA GPU SDK/Driver PTX JIT compatibility

8. **System Prerequisites**
   - Running BOS/CFS sessions
   - Documentation packages availability
   - HSM duplicate events
   - Switch admin password in vault

9. **Architecture-Specific Issues**
   - aarch64 crash utility version check

## Usage

### Basic Usage
```bash
./pre_upgrade_checks.sh
```

### Running on Target System
```bash
# Copy to the system
scp pre_upgrade_checks.sh root@ncn-m001:/root/

# SSH to the system
ssh root@ncn-m001

# Run the script
./pre_upgrade_checks.sh
```

### Output
The script provides:
- **Color-coded output:**
  - 🟢 **Green (PASS)**: Check passed successfully
  - 🟡 **Yellow (WARNING)**: Issue found but not critical
  - 🔴 **Red (FAIL)**: Critical issue that must be addressed
  - 🔵 **Blue (INFO)**: Informational messages

- **Detailed log file:**
  - Saved to: `/etc/cray/upgrade/csm/pre-checks/pre_upgrade_checks_YYYYMMDD_HHMMSS.log`
  - Contains complete output with timestamps
  - Useful for documentation and troubleshooting

### Exit Codes
- `0`: All checks passed
- `1`: One or more critical failures (must fix before upgrade)
- `2`: Warnings present (review recommended)

## Example Output

```
╔════════════════════════════════════════════════════════════════╗
║  CSM Upgrade Pre-Installation Check Script                    ║
║  Target: CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)             ║
║  Date: Mon Feb  3 14:30:00 PST 2026                           ║
╚════════════════════════════════════════════════════════════════╝

========================================
System Prerequisites
========================================

[CHECK 1] Checking for running BOS sessions
✓ PASS: No running BOS sessions

[CHECK 2] Checking for running CFS sessions
✓ PASS: No running CFS sessions

...

========================================
Pre-Upgrade Check Summary
========================================

Total Checks: 25
Passed: 18
Warnings: 5
Failed: 2

Log file: /etc/cray/upgrade/csm/pre-checks/pre_upgrade_checks_20260203_143000.log

⚠ CRITICAL: 2 checks failed. Address these issues before proceeding with upgrade.
```

## Interpreting Results

### Critical Failures (Red)
These **must** be addressed before starting the upgrade:
- Active IUF/BOS/CFS sessions
- Nexus storage >80% full
- Required Kafka topics missing
- Helm releases stuck in uninstalling state

### Warnings (Yellow)
Review these and take action if applicable to your system:
- Firmware version warnings (if you have specific hardware)
- Configuration recommendations
- Version-specific compatibility notes

### Informational (Blue)
Context and guidance for manual checks:
- Documentation links
- Related Jira ticket numbers
- Manual verification steps

## Integration with Upgrade Workflow

Run this script at the following points:

1. **Before starting preparation (Phase 1)**
   - Initial validation
   - Identify issues early

2. **After preparation, before IUF (Before Phase 2)**
   - Verify all prep work is complete
   - Confirm system readiness

3. **After fixing any issues**
   - Re-run to verify fixes
   - Document clean state

## Manual Checks Not Covered

Some checks require manual verification:
- Actual EX254n blade hardware presence and firmware versions
- Complete fabric topology analysis
- Application-specific compatibility
- Custom configurations and site-specific issues

Refer to the main documentation for these manual checks.

## Troubleshooting

### Script Fails to Run
```bash
# Ensure script is executable
chmod +x pre_upgrade_checks.sh

# Check for required commands
which kubectl
which helm
which cray
```

### "Command not found" Warnings
These are expected if:
- Running on a non-management node
- Specific products (Slurm, PBS) not installed
- Commands not in PATH

The script gracefully handles missing commands and provides appropriate warnings.

### Log File Location Issues
If log directory cannot be created:
```bash
# Manually create directory
mkdir -p /etc/cray/upgrade/csm/pre-checks

# Or modify LOG_DIR in script to use /tmp
```

## Customization

You can customize the script for your environment:

### Add Custom Checks
Add functions following this pattern:
```bash
check_custom_issue() {
    print_header "Custom Check Category"
    
    print_check "Description of what you're checking"
    # Your check logic here
    if [ condition ]; then
        print_fail "Error message"
        log_message "       Additional details"
    else
        print_pass "Success message"
    fi
}
```

Then add to main():
```bash
check_custom_issue
```

### Modify Thresholds
Adjust numeric thresholds as needed:
```bash
# Nexus space warning threshold (default: 80%)
if [ "$USAGE" -gt 80 ]; then

# Change to more/less strict:
if [ "$USAGE" -gt 70 ]; then  # More strict
if [ "$USAGE" -gt 90 ]; then  # Less strict
```

## Related Documentation

- **Main Upgrade Summary**: [CSM_Upgrade_25.3.2_to_25.9.0_Summary.md](CSM_Upgrade_25.3.2_to_25.9.0_Summary.md)
- **CSM 1.7 Documentation**: https://cray-hpe.github.io/docs-csm/en-17/
- **Known Issues**: See "Known Issues and Workarounds" section in main summary

## Version History

- **v1.0** (2026-02-03): Initial release
  - Comprehensive checks for all documented known issues
  - Color-coded output with detailed logging
  - Exit codes for automation integration

## Support

For issues with the script:
1. Check log file for detailed error messages
2. Verify prerequisites (kubectl, helm, cray CLI)
3. Consult main upgrade documentation
4. Contact HPE support with log file

For upgrade-specific issues:
- Refer to CSM documentation
- Check Jira tickets referenced in warnings/failures
- Use HPE support channels
