# CSM Pre-Upgrade Validation Suite

Comprehensive read-only validation scripts for HPE Cray EX system upgrades from CSM 25.3.2 (1.6.2) to CSM 25.9.0 (1.7.0). These scripts identify and document known issues early in the upgrade process to ensure system readiness and prevent upgrade failures.

## Overview

This repository provides production-ready pre-upgrade health check scripts that validate system readiness across multiple CSM components and subsystems. The scripts perform non-destructive checks, generate detailed logs, and provide clear guidance on issues found.

**Target Upgrade Path:** CSM 25.3.2 (1.6.2) → CSM 25.9.0 (1.7.0)

## Scripts

### pre_upgrade_checks-1.sh
**Purpose:** Deep health checks based on recommended customer commands

- Runs comprehensive system validation using kubectl, helm, cray CLI, and other tools
- Organizes output into passed/failed categories
- Generates timestamped logs for documentation
- Validates deeper system state beyond basic availability checks

**Usage:**
```bash
chmod +x scripts/pre_upgrade_checks-1.sh
./scripts/pre_upgrade_checks-1.sh
```

### pre_upgrade_checks-2.sh
**Purpose:** Complete pre-install and pre-upgrade validation framework

- Full validation suite covering all known upgrade blockers
- Supports both pre-install and pre-upgrade modes
- Color-coded output for easy issue identification
- Comprehensive logging with detailed results

**Usage:**
```bash
chmod +x scripts/pre_upgrade_checks-2.sh
./scripts/pre_upgrade_checks-2.sh
```

## Validation Coverage

### CSM Core Components
- Active IUF (Integrated Upgrade Framework) sessions
- Nexus repository space utilization (80% threshold warning)
- Kafka CRD (Custom Resource Definition) configuration
- Container image signing and verification readiness

### System Prerequisites
- Running BOS (Boot Orchestration Service) sessions
- Running CFS (Configuration Framework Service) sessions
- HSM (Hardware State Manager) duplicate events
- Switch admin credentials in vault
- Documentation packages availability

### Application Stacks
- **CSM Diags:** Slurm configuration, multi-tenancy checks, current installation status
- **Hardware Firmware Pack (HFP):** EX254n blade firmware versions, FAS loader status
- **Slingshot Host Software (SHS):** SS10 compatibility, MPI job limits, CXI service config
- **Slingshot Fabric:** Certificate Manager health, filesystem space, Velero backup status
- **System Monitoring Application (SMA):** Helm release states, OpenSearch pod health, Kafka topics, LDMS compatibility
- **User Services Software (USS):** PBS Pro version, Slurm version, NMD configuration, GPU compatibility
- **Architecture-Specific:** aarch64 crash utility validation

### Infrastructure Health
- Kubernetes node status
- Critical system pods (kube-system, services, nexus, vault namespaces)
- Ceph storage health (when available)
- Network connectivity and configuration
- Disk space and storage validation

## Output and Logging

### Console Output
- **Color-coded format:**
  - 🟢 **Green (PASS)** - Check succeeded
  - 🟡 **Yellow (WARNING)** - Potential issue, review recommended
  - 🔴 **Red (FAIL)** - Critical blocker, must be addressed
  - 🔵 **Blue (INFO)** - Informational messages

### Log Files
- **Location:** `/etc/cray/upgrade/csm/pre-checks/`
- **Naming:** `checks_YYYYMMDD_HHMMSS/` (timestamped directories)
- **Organization:**
  - `passed/` - Successful check logs
  - `failed_warnings/` - Issues requiring attention

### Exit Codes
- `0` - All checks passed, system ready for upgrade
- `1` - One or more critical failures detected
- `2` - Warnings present, review recommended

## Requirements

### System Requirements
- Bash shell (version 4.0+)
- Root or equivalent privileges for full validation
- Management node access recommended

### Required Tools
The scripts gracefully handle missing tools with appropriate warnings. For full validation, ensure:
- `kubectl` - Kubernetes cluster interaction
- `helm` - Helm chart and release management
- `cray` - Cray CLI for system operations
- `iuf` - IUF session status
- `vault` - Credential management
- `nexus` - Repository management

Optional but recommended:
- `ceph` - Ceph storage health (if applicable)
- `jq` - JSON processing

## Quick Start

### 1. Prepare Scripts
```bash
cd cpv/scripts
chmod +x pre_upgrade_checks-*.sh
```

### 2. Run Pre-Upgrade Validation
```bash
# Run main pre-upgrade check
./pre_upgrade_checks-1.sh
./pre_upgrade_checks-2.sh
```

### 3. Review Results
- Check console output for any FAIL or WARNING items
- Review log files in `/etc/cray/upgrade/csm/pre-checks/`
- Refer to [PRE_UPGRADE_CHECKS_README.md](docs/PRE_UPGRADE_CHECKS_README.md) for issue explanations

### 4. Address Issues
- Critical FAILs must be resolved before proceeding
- WARNINGs should be reviewed and handled as appropriate for your environment

## Documentation

For detailed information about specific checks and how to address issues:

- **[PRE_UPGRADE_CHECKS_README.md](docs/PRE_UPGRADE_CHECKS_README.md)** - Comprehensive explanation of all checks, expected results, and troubleshooting

- **[PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md](docs/PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md)** - Guide for extending scripts with new validation checks using CSM documentation

- **[CSM_Upgrade_25.3.2_to_25.9.0_Summary.md](docs/CSM_Upgrade_25.3.2_to_25.9.0_Summary.md)** - Complete upgrade checklist with software versions, new features in CSM 1.7.0, and integration with official HPE documentation


## Troubleshooting

### Scripts Not Executable
```bash
chmod +x scripts/pre_upgrade_checks-*.sh
```

### Command Not Found
- Verify required tools are in system PATH
- Scripts handle missing commands gracefully with warnings
- Some checks will be skipped if tools are unavailable


### Permission Denied
- Ensure running with appropriate privileges (root recommended)
- Some checks require elevated permissions to access system state

## Development & Contributing

### Adding New Checks
See [PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md](docs/PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md) for detailed instructions on:
- Leveraging CSM official documentation
- Using helper functions for consistency
- Writing read-only validation code
- Proper logging and output formatting

### Best Practices
- Keep all checks read-only (no modifications to system state)
- Use provided helper functions for consistent output and logging
- Add clear, descriptive check names and messages
- Document new checks with references to CSM documentation
- Test with both passing and failing conditions

## Support & Issues

For issues with the validation scripts or questions about upgrade readiness:
1. Review relevant documentation in the `docs/` directory
2. Check log files for detailed error information
3. Cross-reference with official CSM upgrade documentation

## Version Information

- **Script Version:** 1.1
- **Target CSM Version:** 25.9.0 (1.7.0)
- **Source CSM Version:** 25.3.2 (1.6.2)
- **Last Updated:** February 2026

## License & Usage

These scripts are designed for use during CSM system upgrades. They are non-destructive and perform read-only validation only.
