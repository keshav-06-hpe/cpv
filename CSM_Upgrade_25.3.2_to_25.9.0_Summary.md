# CSM Upgrade 25.3.2 (1.6.2) to CSM 25.9.0 (1.7.0) Checklist Summary

## Document Overview

This document provides a comprehensive checklist and procedure for upgrading HPE Cray EX System Software Stack from CSM 25.3.2 (CSM 1.6.2) to CSM 25.9.0 (CSM 1.7.0). The upgrade includes multiple software products and components.

**System:** Creek (Training System)  
**Network Type:** Cassini  
**Documentation Source:** HPE Cray EX System Software Stack Installation and Upgrade Guide for CSM (S-8052)

---

## Software Versions

### Target Software Versions (CSM 25.9.0)

| Product | Version |
|---------|---------|
| CSM | 1.7.0 |
| CSM Diags | 1.7.7 |
| HFP (HPE Firmware Pack) | 25.7.1 |
| hpc-csm-software-recipe | 25.9.0 |
| SDU (System Diagnostic Utility) | 3.6.2 (cray-sdu-rda 3.6.2) |
| SMA (System Monitoring Application) | 1.11.7 |
| USS (User Services Software) | 1.4.0-120-csm |
| CPE | 25.9.11 |
| Slingshot | 2.3.1-1796 |
| SHS (Slingshot Host Software) | 13.0.0-91-sle15-sp6-x86-64 |
| Slurm | 25.05.0 (Used 25.05.3) |
| PBS Pro | 2025.1.0 (Used 2025.2.1) |

### SUSE OS Versions
- SUSE Backports/Products/Updates/Supplement for SLE15SP6 (both aarch64 and x86_64): 25.7.250709

### GPU Software (Optional)
**NVIDIA:**
- SDK: 25.5
- Driver: 570.124.06
- datacenter-gpu-manager rpm (3.x or 4.x)

**AMD:**
- ROCm: 6.4
- amdgpu driver: 6.4

---

## Major New Features in CSM 1.7.0

### CSM Core Features
1. **Container Signing and Verification**
   - All container images are signed
   - Signature validation during CSM build
   - Kyverno policies enforce container image signature verification

2. **Enhanced iSCSI SBPS (Scalable Boot Projection Service)**
   - Administrators can select which worker NCNs are enabled as iSCSI targets
   - Change from CSM 1.6 where all worker NCNs were enabled

3. **Console Logs via Cray CLI**
   - Console logs and interaction available through Cray CLI
   - Tenant-aware through ConMan

4. **IPv6 Support**
   - IPv6 enablement for fresh installs and deployed systems
   - cloud-init and SLS data for IPv6 on CMN and CHN
   - Supports IPv6 NTP servers
   - Supports IPv6 site link (exclusively IPv4 or IPv6)

5. **IUF Enhancements**
   - Supports customized images and CFS configurations for rebuilding nodes
   - Can reboot worker and storage NCNs without rebuilding them

6. **Security Improvements**
   - Spire node attestation can use TPM chips
   - Updated HMS services with latest CVE fixes
   - Pod Security Standards (PSS) Baseline policies enforced via Kyverno
   - Default Kubernetes certificate validity increased from 1 year to 3 years

7. **Rack Resiliency (Technology Preview)**
   - Optional feature for management plane protection against rack-level failures
   - Disabled by default
   - Can only be enabled during upgrade from CSM 1.6 to 1.7 or fresh install

8. **CNI Change: Weave to Cilium**
   - Fresh install uses Cilium by default
   - Upgrade from CSM 1.6 migrates CNI from Weave to Cilium

### USS (User Services Software) Features
1. **Slurm Multitenancy Support**
   - Supports multitenancy using Kubernetes operator pattern
   - Isolated tenants with separate Slurm instances
   - Dedicated Slurm configuration, authentication, and accounting per tenant

2. **Updated GPU Support**
   - AMD ROCm 6.4 and amdgpu 6.4 (new default)
   - NVIDIA SDK 25.5 and driver 570.124.06 (new default)

3. **UAN Networking**
   - CAN/CHN interface supports IPv4-only or dual-stack (IPv4+IPv6)
   - Does not support IPv6-only

4. **UAI Improvements**
   - Users can log in multiple times to the same UAI session
   - Administrators can configure multiple UAI images

5. **PALS Improvements**
   - Improved stdout/stderr performance
   - New options for file output and application timeout
   - Supports PMIx tool attach and query

6. **DVS Changes**
   - DVS disabled by default on all nodes
   - DVS and LNet RPMs no longer installed by default on NCN worker nodes
   - Debug files renamed: `request_log_min_time_secs` and `fs_log_min_time_secs`

7. **Content Projection Service (CPS) Removed**
   - Replaced by Scalable Boot Projection Service (SBPS)

### SMA Features
1. **Grafana Alerting Framework**
   - Alerts for telemetry and Redfish events
   - Viewable in Alertmanager (Unified Alerting)

2. **Flow Improvements**
   - Creates four pods instead of one (better scalability and fault tolerance)
   - New metric: `consumer_poll_failures`
   - New Flow Dashboard in System Management Health

3. **AIOps Improvements**
   - Image size reduced from 4.06 GB to 2.26 GB
   - Improved failure prediction model (faster, more accurate, smaller)
   - Alert Processor improvements (archived alerts in Grafana, realtime in AlertManager)

4. **Dashboard Changes**
   - New: Flow Dashboard
   - Renamed: Multiple AIOps dashboards
   - Removed: Alerta, Cluster Health Check, Prometheus Alerts Overview

5. **Removed Features**
   - elastalert
   - Monasca
   - Telemetry API (deprecated)

### Slingshot 2.3.1 Features
1. **Routing Initialization Fixes**
   - Contains fixes for switch initialization issues in 2.3.0
   - Additional switch monitor to observe, correct, and log issues

2. **Hardware-based Network Collectives**
   - Improved scalability/routing
   - Bug fix for Collectives readiness

3. **IPv6 Improvements**
   - Fixed bug with IPv6 multicast traffic classification in TCAM
   - API to drop or flood IPv6 multicast traffic

4. **Fat Tree Improvements**
   - Multicast traffic flow fixes
   - Edge port workflow support
   - Correct rules for edge port creation

5. **HPE Slingshot 200Gbps/400Gbps Interoperability**
   - Validated scenario for 200Gbps Switch with 400Gbps NIC

6. **Routing Bias Changes**
   - Dedicated Access (DA): non-minimal → no-bias
   - Bulk Data (BD): non-minimal → no-bias
   - Ethernet: non-minimal → no-bias
   - Low Latency (LL): non-minimal → minimum bias
   - Best Effort (BE): remains at non-minimal bias

### SHS (Slingshot Host Software) 13.0.0
1. **HPE Slingshot 400Gbps NIC Support**
2. **Libfabric 2.2 Upgrade**
   - Supports more than 252 processes
   - Enhanced VNI handling for DAOS
3. **GPU Support**
   - AMD 6.4 and NVIDIA 25.5 with 570 driver
4. **SoftRoCE Support**
   - SLES SP6 (x86 only)
5. **COS and CSM Product Stream Removal**
   - Use SLES for all CSM installations

---

## Known Issues and Workarounds

### CSM Issues
1. **Systems with CSM 1.6 or earlier fresh installing CSM 1.7 must regenerate management switch configuration** due to Cray Site Init (CSI) tool behavior changes
   - Link: https://cray-hpe.github.io/docs-csm/en-17/troubleshooting/#known-issues
   - 37 known issues documented

2. **IUF may not run next stage for an activity**
   - During CSM upgrade, IUF reports multiple sessions in progress
   - Workaround: See docs-csm 1.6 section on IUF stage issues
   - Related: CAST-38971, CAST-38972, CAST-38968, CAST-38980, CAST-38981, CAST-38982

### CSM Diags Issues
1. **AllowedRAMSpace Setting Required**
   - For Slurm WLM: Ensure `AllowedRAMSpace=100` in `/etc/slurm/cgroup.conf` on compute nodes before running CSM Diags
   - Related: CASMDIAG-1733, CASMDIAG-1655

2. **Multi-tenancy Installation**
   - Must uninstall existing CSM Diags before multi-tenancy installation
   - Run `switch_to_multitenancy.sh` script before repackaging

3. **IUF pre-install-check failure**
   - May fail with error on `cray-hms-badger-job-api` restart
   - Solution: Uninstall CSM Diags and rerun IUF
   - Related: CASMDIAG-1734

### HFP Issues
1. **EX254n Blade Firmware Issue**
   - CcNc firmware version 1.10.1-12 (from HFP 25.6.1) has booting issue
   - HFP 25.7.1 reverted to older version 1.9.9-46
   - Systems with EX254n blades should not use CcNc firmware 1.10.1-12

2. **Omitted NVIDIA Firmware**
   - Several NVIDIA firmware packages still omitted (will be updated in future HFP release)

3. **FAS Loader Issues**
   - `cray fas loader nexus create` may fail during `post-install-test-fas.sh`
   - Manual intervention required if loaderStatus returns "busy" after 200 seconds
   - Related: Check status with `cray fas loader list --format json | grep loaderStatus`

### SHS Issues
1. **Libfabric XRC Non-functional (Issue 2160777)**
   - Use UCX instead of Libfabric with XRC
   - For open-source Libfabric: Set `FI_VERBS_PREFER_XRC=0` for MPI jobs with 64+ ranks

2. **MTU Change Crash (Issue 3127871)**
   - System may crash/reboot when changing MTU size with high traffic
   - Avoid changing MTU under heavy load

3. **CXI Service VNI Update Not Supported (Issue 3110032)**
   - As of SHS 13.0, updating VNIs of existing CXI Service is not supported
   - `cxi_service` utility won't work for VNI updates

4. **AMA Assignment for Slingshot 400GB Switch (Issue 2802789)**
   - Changing baseMacPrefix requires all connected nodes to be rebooted

5. **libfabric MR Cache Deadlock (Issue 2215092)**
   - When doing RDMA with device memory, memhooks cannot be used
   - Use userfaultfd or kdreg2 as memory monitor:
     - `FI_MR_CACHE_MONITOR=userfaultfd`
     - `FI_MR_CACHE_MONITOR=kdreg2`

6. **SS10 Not Supported**
   - Continue using SHS-v12.0.x for SS10 Systems

7. **SLURM/PALS >252 Ranks Issue**
   - Using SLURM 25.05 or PALS 1.7.1 with >252 ranks per node may fail
   - libfabric error: 'Command failure' due to RGID sharing issue
   - Recommend using earlier versions until resolved

### Slingshot Issues
1. **Velero Backups Show Partially Failed (Issue 2300387)**
   - Follow "Backup and restore of fabric configuration" in HPE Slingshot Administration Guide

2. **Certificate Manager Keystore Corruption (Issue 3039322)**
   - Can occur if filesystem full during `fmn-create-certificate`
   - Can occur if manually tampered
   - Pre-1.7.0: Could occur with parallel certificate commands
   - See Slingshot Troubleshooting Guide Section 6.3.1 for recovery

### SMA Issues
1. **LDMS Configuration File Incompatibility**
   - SMA 1.10.15+ includes upgraded LDMS with incompatible config files
   - Action required at deliver-product stage (see IUF Stage Details for SMA)
   - **Note:** Should have been handled in CSM 1.6/SMA 1.10 upgrade

2. **Helm Chart Release Failure During Upgrade**
   - Previous release may be stuck in uninstalling state
   - Stale Helm secrets left behind
   - Affects: `sma-aiops`, `sma-opensearch-cron`, `sma-vm-cluster`, `sma-monasca`
   - Manual removal of secrets required

3. **OpenSearch Pods Fail After Upgrade**
   - Due to Kubernetes upgrade
   - Master pods 0, 1, 2 may fail to come up
   - See Section 6.2.5 OpenSearch Upgrade Issue

4. **Missing Kafka Topics on Fresh Install**
   - Some topics may not be generated
   - Must create manually: `cray-telemetry-metric` and related topics
   - Check with: `kubectl -n sma exec -t cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep cray-telemetry-metric`

5. **Pending Operation for sma-svc-init**
   - Helm upgrade fails due to concurrent operation in progress

### USS Issues
1. **PBS PALS Launches Fail (PBS Professional 2024)**
   - Error messages in PBS MOM logs
   - See Section 13.12.3 for workaround

2. **slurmctld Fails After Upgrading to Slurm 24.05**
   - Instant On support disabled causes failure
   - Update default Slurm configuration
   - See Section 13.14.6

3. **cray-slurmdbd Helm Chart Fails During deploy-product**
   - PXC certificate errors
   - Percona XtraDB Cluster operator fails to set up validating webhook certificate
   - See Section 13.14.11

4. **NVIDIA PTX JIT Compilation Failure**
   - Forward-compatibility conflicts between SDK 25.5 (CUDA 12.9) and driver 570.124.06 (CUDA 12.8)
   - **Workaround:** Use CUDA 11.8 modulefiles and paths instead of CUDA 12.9

5. **PBS_cray_atom Hook Fails (PBS 2025.2.0)**
   - Error: "Not supported URL scheme http+unix"
   - See Section 13.12.4

6. **PALS Applications with PMIx May Fail**
   - Error: "shepherd died from signal 6"
   - **Workaround:** Add `--ppn` option to specify processes per node

7. **crash Utility for aarch64 64KB Page Size**
   - Default crash 8.0.4 cannot open dumps from 64KB page size kernels
   - Need crash 8.0.6 (not yet in SLES for aarch64)
   - Temporary solution: Use binary compiled from crash-8.0.6 source

8. **cos-config-service Not Removed on Upgrade**
   - Continues to run after upgrade
   - Must manually uninstall: `helm uninstall -n services cos-config-service`

9. **NMD Fails for Dumps >80 GB**
   - Update S3 upload chunk size to 128 MB
   - See Section 8.4

10. **Application Core Dump Behavior Changed**
    - Now handled by systemd-coredump
    - See SUSE Linux Enterprise Server Documentation
    - Link: https://documentation.suse.com/sles/15-SP6/html/SLES-all/cha-tuning-systemd-coredump.html

11. **USS amd_hsmp Driver Superseded**
    - In-kernel AMD driver is now preferred
    - `cray-power-management` requires in-kernel driver
    - See Section 20 for removal of USS amd_hsmp module

---

## Important Links and Documentation

### Main Documentation
- **CSM Documentation (1.7):** https://cray-hpe.github.io/docs-csm/en-17/
- **CSM Upgrade Guide:** https://cray-hpe.github.io/docs-csm/en-17/upgrade/
- **CSM Release Notes:** https://cray-hpe.github.io/docs-csm/en-17/release_notes/
- **CSM Troubleshooting:** https://cray-hpe.github.io/docs-csm/en-17/troubleshooting/
- **IUF Workflows:** https://cray-hpe.github.io/docs-csm/en-17/operations/iuf/workflows/upgrade_csm_and_additional_products_with_iuf/

### Product Documentation Access
- **GitHub Internal (HPE):** https://github.hpe.com/hpe/hpc-csm-software-recipe/blob/release/cr_2025/vcs/product_vars.yaml.in
- **Cray-HPE GitHub:** https://cray-hpe.github.io/docs-csm/en-17/upgrade/
- **Internal Tarball Access:** https://cflmetint01.hpc.amslabs.hpecorp.net/public-html/hpc-ch-sdu-tarfile/csm/3.6.2/

### Additional Resources
- **NVIDIA Documentation:** https://docs.nvidia.com/datacenter/tesla/index.html
- **CUDA Compatibility Docs:** (Referenced for PTX JIT issues)
- **AMD GPU Content:** https://repo.radeon.com
- **NVIDIA GPU Content:** https://developer.download.nvidia.com

---

## Good Practices

### Pre-Upgrade Preparation
1. **Documentation Review**
   - Always review release notes and known issues before starting
   - Install latest documentation for both CURRENT and TARGET CSM versions
   - Check customer advisories

2. **Health Checks**
   - Run extended system health checks before upgrade
   - Record pre-existing problems
   - Save system state using `/usr/share/doc/csm/upgrade/scripts/upgrade/util/pre-upgrade-status.sh`
   - Create health directory: `mkdir -p /etc/cray/upgrade/csm/healthcheck/$(date "+%Y%m%d")`

3. **Nexus Space Management**
   - Check Nexus space usage before upgrade
   - Prune old content if needed (recommended over increasing PVC size)
   - Link: https://cray-hpe.github.io/docs-csm/en-17/operations/package_repository_management/nexus_space_cleanup/

4. **Backup Critical Data**
   - Export Nexus data (optional but recommended)
   - Backup fabric configuration (for Slingshot)
   - Record configuration choices and tuning

5. **Session Management**
   - Check for running sessions (BOS, CFS) before starting
   - Ensure no conflicting operations in progress

### During Upgrade
1. **Use Typescript for Logging**
   - Start typescript with timestamp prompts
   - Save all typescripts to `/etc/cray/upgrade/csm/logs`
   - Example: `script -af /etc/cray/upgrade/csm/logs/csm_upgrade_prep.window1.$(date "+%Y%m%d").txt`

2. **Follow IUF Stage Workflow**
   - Use IUF (Install and Upgrade Framework) for orchestrated upgrades
   - Follow stage sequence: process-media → pre-install-check → deliver-product → deploy-product → management-nodes-rollout
   - Track activity with `ACTIVITY_NAME` variable

3. **Monitor Argo UI**
   - Access Argo workflows UI for stage monitoring
   - Use port forwarding to access services
   - Monitor workflow progress and failures

4. **Incremental Validation**
   - Validate each IUF stage before proceeding
   - Check for errors using `get_errors` tool
   - Run health checks between major stages

### GPU Content Management
1. **NVIDIA Content**
   - Download SDK and driver separately
   - Expand driver RPM with `rpm2cpio` in correct directory
   - Upload to Nexus using `gpu-nexus-tool`
   - Verify upload (note: verification fails in air-gapped systems)

2. **AMD Content**
   - Download ROCm SDK and amdgpu driver from repo.radeon.com
   - Maintain correct directory structure for `gpu-nexus-tool`
   - Upload before `prepare-images` stage

3. **SMA DCGM Requirement**
   - For NVIDIA: Add datacenter-gpu-manager RPM to Nexus repository
   - Create dedicated Nexus repo: `sma-dcgm`
   - Multiple versions available (3.3.x and 4.x)

### Slurm Custom Build
1. **Build from Source When Needed**
   - Required before CSM Diags installation (if using Slurm WLM)
   - Use Podman with SLES15SP6 base image
   - Include necessary plugins: PMIx, NVML, RSMI, HPE Slingshot
   - Copy built RPMs to `/etc/cray/upgrade/csm/slurm/x86_64/`

2. **Dockerfile Customization**
   - Enable/disable plugins based on system requirements
   - Adjust repository versions (e.g., SHS 13.0 vs 13.1)
   - Include GPU support if needed

### Configuration Management
1. **Admin Directory Structure**
   - Populate `${ADMIN_DIR}` with:
     - `product_vars.yaml`
     - `site_vars.yaml`
     - `bootprep/compute-and-uan-bootprep.yaml`
     - `bootprep/management-bootprep.yaml`

2. **Customizations.yaml Updates**
   - Required for Slurm, PBS, CSM Diags, and UAN products
   - Update before `deliver-product` stage
   - Review product-specific documentation

3. **Small System Adjustments**
   - Systems with only 3 worker nodes get automatic adjustments during `pre-install-check`
   - CSM prerequisites.sh handles service request modifications

### Post-Upgrade Validation
1. **Component Health**
   - Run CSM health checks
   - Validate HSM, WLM microservices
   - Check FAS, S3, Nexus services

2. **Network Validation**
   - Check Slingshot fabric health
   - Look for flapping links or connectivity issues
   - Verify switch firmware versions

3. **Service Verification**
   - Test NMD (Node Memory Dump) by crashing a test node
   - Run SDU scenarios: health, inventory, daily, triage
   - Validate DVS, LNet if used

4. **Application Testing**
   - Test MPI jobs with appropriate rank counts
   - Verify GPU applications (NVIDIA/AMD)
   - Validate PALS/PMIx functionality

### Troubleshooting Best Practices
1. **Check Logs Systematically**
   - IUF logs: `/root/output.log`
   - CSM stage state: `/etc/cray/upgrade/csm/{CSM_VERSION}/{NAME_OF_NODE}/state`
   - Argo workflow logs in UI

2. **Known Issue Consultation**
   - Always check known issues list (37 issues for CSM 1.7)
   - Review product-specific troubleshooting guides
   - Search Jira tickets for similar problems

3. **Air-Gapped System Considerations**
   - `gpu-nexus-tool repo check` will fail (expected)
   - Use `repo list` instead for verification
   - Pre-download all content before starting

4. **Service Recovery**
   - If Helm charts timeout, check pod status
   - Remove stale Helm secrets if stuck in uninstalling state
   - Manually create missing Kafka topics if needed

---

## Upgrade Workflow Overview

### Phase 1: Preparation (Before IUF)
1. Install latest documentation (current CSM 1.6.2)
2. Fix Kafka CRD issue
3. Export Nexus data (optional)
4. Remove duplicate HSM postgres events
5. Add switch admin password to vault
6. Configure SNMP on management network switches
7. Check for running sessions
8. Create activity directories
9. Install latest documentation (target CSM 1.7.0)
10. Download product media
11. Read README files

### Phase 2: Product Delivery (IUF Stages)
1. **process-media**
   - Extract and inventory products
   - Handle CSM Diags multi-tenancy if needed

2. **pre-install-check**
   - Run verification tests
   - CSM prerequisites.sh executed as hook
   - Upload NCN images

3. **Manual GPU Content Upload** (before deliver-product)
   - NVIDIA SDK and driver
   - AMD ROCm and amdgpu
   - SMA DCGM RPM

4. **Manual Slurm Build** (if needed for CSM Diags)
   - Build from source using Podman
   - Include required plugins

5. **deliver-product**
   - Upload content to Nexus
   - Update product catalog
   - Modify customizations.yaml
   - Handle product-specific hooks

### Phase 3: Deployment
1. **deploy-product**
   - Deploy Helm charts
   - Apply networking manifests (CSM post-hook)
   - Upgrade Kubernetes control plane (CSM post-hook)

2. **management-nodes-rollout**
   - Deploy CSM services (CSM pre-hook)
   - Check health
   - Rebuild/reboot NCNs

### Phase 4: Post-Upgrade Configuration
1. Enable optional features (xname validation, COCN, UAI, etc.)
2. Configure LDAP/Keycloak
3. Set up DVS/LNet if needed
4. Configure WLM plugins
5. Run validation tests (SDU scenarios)

### Phase 5: Validation and Testing
1. Extended health checks
2. Fabric health validation
3. Application testing
4. NMD testing

---

## IUF Stages Reference

### IUF Stage Descriptions
- **process-media:** Inventory and extract products
- **pre-install-check:** Verify prerequisites
- **deliver-product:** Upload content to Nexus and product catalog
- **deploy-product:** Deploy Helm charts and services
- **prepare-images:** Build NCN and node images
- **management-nodes-rollout:** Rebuild/reboot management nodes
- **managed-nodes-rollout:** Update compute and application nodes

### Access Argo UI for Monitoring
```bash
# Get Argo service info
kubectl -n argo get vs cray-argo -o yaml | grep workflows
kubectl -n argo get svc cray-nls-argo-workflows-server

# Port forwarding (example from document)
ssh root@creek -L 8082:10.30.201.151:2746 -L 3000:10.23.153.139:3000 \
  -L 8081:10.17.6.14:80 -L 8084:10.24.204.239:80 -L 8085:10.30.204.190:8080 \
  -L 8086:10.30.78.203:8429 -L 9090:10.18.176.157:20001 \
  -L 5601:10.27.62.164:5601 -L 5000:10.20.198.73:5000 \
  -L 8089:10.16.14.216:80 -L 8070:10.26.219.234:80

# Access URLs (HTTP, not HTTPS)
# Argo UI: http://localhost:8082
# System Management Health Grafana: http://localhost:8081
# SMA Grafana: http://localhost:3000
# vmalert: http://localhost:8085
# vmagent: http://localhost:8086/targets
# Kiali: http://localhost:9090
# SMA PCIM: http://localhost:8084
# OpenSearch: http://localhost:5601
# MLflow: http://localhost:5000
# CFS ARA: http://localhost:8089
# Cilium Hubble: http://localhost:8070
```

---

## Critical Environment Variables

```bash
# Activity and directory setup
ACTIVITY_NAME=upgrade-recipe-25.9.0
MEDIA_DIR="/etc/cray/upgrade/csm/media/${ACTIVITY_NAME}"
ACTIVITY_DIR="/etc/cray/upgrade/csm/iuf/${ACTIVITY_NAME}"
ADMIN_DIR="/etc/cray/upgrade/csm/admin"

# CSM versions
CSM_RELEASE=1.7.0  # Target version
SLES_VERSION=15sp6

# Architecture
ARCH=x86_64  # or aarch64
```

---

## Special Considerations

### IPv6 Enablement
- Available for fresh installs and upgrades
- Supports dual-stack or IPv6-only (site link)
- UANs support dual-stack, not IPv6-only
- Requires CSI (Cray Site Init) major version bump

### Cilium CNI Migration
- Fresh installs use Cilium by default
- Upgrades automatically migrate from Weave to Cilium
- Monitored through IUF upgrade process

### Rack Resiliency
- Technology preview feature
- Must be enabled during CSM 1.6→1.7 upgrade or fresh install of 1.7
- Cannot be enabled after installation
- Provides protection against rack-level failures

### Certificate Management
- Default validity increased to 3 years
- Modifiable through configuration
- Spire can use TPM for node attestation

### Pod Security
- Pod Security Policies (PSP) removed
- Pod Security Standards (PSS) enforced via Kyverno
- Baseline policies applied
- Image verification policy in Enforce mode

---

## Jira Tickets and Issues Referenced

### Open Issues Mentioned
- CASMTRIAGE-8767 (Creek system upgrade tracking)
- CASMTRIAGE-8826 (Nexus space management)
- CASMTRIAGE-8829 (nexus-export.sh missing path)
- CASMTRIAGE-8830 (nexus-helper.sh status display)
- CASMMON-550 (metallb-speaker alerts)
- CASMDIAG-1732, CASMDIAG-1733, CASMDIAG-1655, CASMDIAG-1734 (CSM Diags issues)
- CAST-38971, CAST-38972, CAST-38968, CAST-38980, CAST-38981, CAST-38982 (IUF issues)
- TECHPUBS-4901, TECHPUBS-4844, TECHPUBS-5304, TECHPUBS-4738 (Documentation)
- HPCCHT3-6009, HPCCHT3-6010 (Testing)
- NETCASSINI-8150 (Slingshot testing issue)

---

## Notes on Air-Gapped Systems

1. **GPU Content Verification Limitation**
   - `gpu-nexus-tool repo check` will fail trying to access external URLs
   - This is expected behavior
   - Use `gpu-nexus-tool repo list` to verify content was uploaded

2. **Pre-Download Requirements**
   - All GPU vendor content must be downloaded on system with internet
   - Transfer to air-gapped system via scp
   - Ensure correct directory structure before upload

3. **Documentation Access**
   - May need to pre-download documentation tarballs
   - Use `wget` commands on internet-connected system
   - Transfer RPMs to air-gapped system

---

## Summary

This upgrade from CSM 25.3.2 (1.6.2) to CSM 25.9.0 (1.7.0) is a significant update with:
- Major version changes for CSM (1.6→1.7)
- CNI migration (Weave→Cilium)
- Security enhancements (container signing, Kyverno policies)
- IPv6 support
- Multiple product updates (Slingshot, SHS, USS, SMA, etc.)

**Key Success Factors:**
1. Thorough pre-upgrade preparation and health checks
2. Following IUF workflow stages in sequence
3. Addressing known issues proactively
4. Proper GPU content management (if applicable)
5. Custom Slurm build if using CSM Diags
6. Post-upgrade validation and testing

**Estimated Timeline:**
- Preparation: Several hours to days (depending on complexity)
- IUF Execution: Several hours per stage
- Validation: 1-2 days minimum

**Support Resources:**
- Slack channel: #hpc-tts-cfa-lab (for Creek system)
- Jira labels: "creek", "creek_upgrade"
- HPE documentation portals
- Internal HPE support channels
