#!/bin/bash
################################################################################
# CSM Extended Pre-Upgrade Health Checks
# Purpose: Run deeper read-only checks based on recommended customer commands
################################################################################

LOG_DIR="/etc/cray/upgrade/csm/pre-checks"
mkdir -p "$LOG_DIR"
LOG_BASE="${LOG_DIR}/extended_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_BASE"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0
FAILED_LABELS=()
WARNING_LABELS=()

record_fail() {
    local label="$1"
    FAILED_LABELS+=("$label")
}

record_warn() {
    local label="$1"
    WARNING_LABELS+=("$label")
}

log_cmd() {
    local label="$1"
    shift
    local out_file="$LOG_BASE/${label}.log"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "[RUN] $*" | tee -a "$out_file"
    "$@" >> "$out_file" 2>&1
    local rc=${PIPESTATUS[0]}
    if [ $rc -eq 0 ]; then
        if ! validate_output "$label" "$out_file" "" "" ""; then
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            record_fail "$label"
            return 1
        fi
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo "[PASS] $label" | tee -a "$out_file"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        echo "[FAIL] $label (exit $rc)" | tee -a "$out_file"
    fi
    return $rc
}

log_shell() {
    local label="$1"
    local cmd="$2"
    local out_file="$LOG_BASE/${label}.log"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "[RUN] $cmd" | tee -a "$out_file"
    bash -c "set -o pipefail; $cmd" >> "$out_file" 2>&1
    local rc=${PIPESTATUS[0]}
    if [ $rc -eq 0 ]; then
        if ! validate_output "$label" "$out_file" "" "" ""; then
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            record_fail "$label"
            return 1
        fi
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo "[PASS] $label" | tee -a "$out_file"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        echo "[FAIL] $label (exit $rc)" | tee -a "$out_file"
    fi
    return $rc
}

FORBIDDEN_GENERIC_REGEX='(^|[^a-z])fail(ed|ure)?([^a-z]|$)|(^|[^a-z])warn(ing)?([^a-z]|$)|(^|[^a-z])error([^a-z]|$)|(^|[^a-z])critical([^a-z]|$)|exception|traceback'

validate_output() {
    local label="$1"
    local out_file="$2"
    local required_regex="$3"
    local forbidden_regex="$4"
    local warn_regex="$5"
    local failed=0

    if ! grep -q "[^[:space:]]" "$out_file"; then
        echo "[FAIL] $label (no output)" | tee -a "$out_file"
        return 1
    fi

    if [ -n "$required_regex" ] && ! grep -Eiq "$required_regex" "$out_file"; then
        echo "[FAIL] $label (missing required pattern)" | tee -a "$out_file"
        failed=1
    fi

    if grep -Eiq "$FORBIDDEN_GENERIC_REGEX" "$out_file"; then
        echo "[FAIL] $label (generic failure pattern detected)" | tee -a "$out_file"
        failed=1
    fi

    if [ -n "$forbidden_regex" ] && grep -Eiq "$forbidden_regex" "$out_file"; then
        echo "[FAIL] $label (forbidden pattern detected)" | tee -a "$out_file"
        failed=1
    fi

    if [ -n "$warn_regex" ] && grep -Eiq "$warn_regex" "$out_file"; then
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        record_warn "$label"
        echo "[WARN] $label (warning pattern detected)" | tee -a "$out_file"
    fi

    return $failed
}

log_cmd_validate() {
    local label="$1"
    local required_regex="$2"
    local forbidden_regex="$3"
    local warn_regex="$4"
    shift 4
    local out_file="$LOG_BASE/${label}.log"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "[RUN] $*" | tee -a "$out_file"
    "$@" >> "$out_file" 2>&1
    local rc=${PIPESTATUS[0]}
    if [ $rc -ne 0 ]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        echo "[FAIL] $label (exit $rc)" | tee -a "$out_file"
        return $rc
    fi

    if ! validate_output "$label" "$out_file" "$required_regex" "$forbidden_regex" "$warn_regex"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        return 1
    fi

    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "[PASS] $label" | tee -a "$out_file"
    return 0
}

log_shell_validate() {
    local label="$1"
    local required_regex="$2"
    local forbidden_regex="$3"
    local warn_regex="$4"
    local cmd="$5"
    local out_file="$LOG_BASE/${label}.log"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "[RUN] $cmd" | tee -a "$out_file"
    bash -c "set -o pipefail; $cmd" >> "$out_file" 2>&1
    local rc=${PIPESTATUS[0]}
    if [ $rc -ne 0 ]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        echo "[FAIL] $label (exit $rc)" | tee -a "$out_file"
        return $rc
    fi

    if ! validate_output "$label" "$out_file" "$required_regex" "$forbidden_regex" "$warn_regex"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        record_fail "$label"
        return 1
    fi

    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "[PASS] $label" | tee -a "$out_file"
    return 0
}

check_cmd() {
    command -v "$1" &> /dev/null
}

print_info() {
    echo "[INFO] $1" | tee -a "$LOG_BASE/extended_checks.info.log"
}

print_warn() {
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    echo "[WARN] $1" | tee -a "$LOG_BASE/extended_checks.info.log"
}

print_summary() {
    local summary_file="$LOG_BASE/extended_checks.summary.log"
    {
        echo "Extended pre-upgrade checks summary"
        echo "Total:   $TOTAL_CHECKS"
        echo "Passed:  $PASSED_CHECKS"
        echo "Failed:  $FAILED_CHECKS"
        echo "Warnings:$WARNING_CHECKS"
        echo "Logs:    $LOG_BASE"
        if [ ${#FAILED_LABELS[@]} -gt 0 ]; then
            echo "Failed checks:"
            printf '  - %s\n' "${FAILED_LABELS[@]}"
        fi
        if [ ${#WARNING_LABELS[@]} -gt 0 ]; then
            echo "Warning checks:"
            printf '  - %s\n' "${WARNING_LABELS[@]}"
        fi
    } | tee -a "$summary_file"
}

print_info "Extended pre-upgrade checks started at $(date)"

# HMS discovery verification scripts
if [ -x /opt/cray/csm/scripts/hms_verification/hsm_discovery_status_test.sh ]; then
    log_cmd_validate "hsm_discovery_status_test" "PASS: hsm_discovery_status_test passed!" "FAIL:|ERROR|Exception|Traceback" "" /opt/cray/csm/scripts/hms_verification/hsm_discovery_status_test.sh
else
    print_warn "Missing: /opt/cray/csm/scripts/hms_verification/hsm_discovery_status_test.sh"
fi

if [ -x /opt/cray/csm/scripts/hms_verification/verify_hsm_discovery.py ]; then
    log_cmd_validate "verify_hsm_discovery" "Cabinet Summary|Cabinet Checks" "FAIL:|ERROR|Exception|Traceback" "" /opt/cray/csm/scripts/hms_verification/verify_hsm_discovery.py
else
    print_warn "Missing: /opt/cray/csm/scripts/hms_verification/verify_hsm_discovery.py"
fi

if [ -x /opt/cray/csm/scripts/hms_verification/run_hardware_checks.sh ]; then
    log_cmd "run_hardware_checks" /opt/cray/csm/scripts/hms_verification/run_hardware_checks.sh
else
    print_warn "Missing: /opt/cray/csm/scripts/hms_verification/run_hardware_checks.sh"
fi

# BOS v1 sessions log check
if check_cmd kubectl; then
    log_shell_validate "bos_v1_session_logs" "" "Received message larger than max" "" "kubectl -n services logs --max-log-requests 50 -l app.kubernetes.io/name=cray-bos | grep -C4 'Received message larger than max' || true"
fi

# cmsdev tests
if [ -x /usr/local/bin/cmsdev ]; then
    log_cmd_validate "cmsdev_test_all" "SUCCESS: All [0-9]+ service tests passed" "FAILED|ERROR" "" /usr/local/bin/cmsdev test -q all
else
    print_warn "Missing: /usr/local/bin/cmsdev"
fi

# Gateway tests
if [ -x /usr/share/doc/csm/scripts/operations/gateway-test/ncn-gateway-test.sh ]; then
    log_cmd_validate "ncn_gateway_test" "Overall Gateway Test Status:[[:space:]]+PASS" "Overall Gateway Test Status:[[:space:]]+FAIL|ERROR" "" /usr/share/doc/csm/scripts/operations/gateway-test/ncn-gateway-test.sh
else
    print_warn "Missing: /usr/share/doc/csm/scripts/operations/gateway-test/ncn-gateway-test.sh"
fi

# BICAN internal test
if [ -x /usr/share/doc/csm/scripts/operations/pyscripts/start.py ]; then
    log_cmd_validate "test_bican_internal" "Overall status:[[:space:]]+PASSED" "FAILED|ERROR" "" /usr/share/doc/csm/scripts/operations/pyscripts/start.py test_bican_internal
else
    print_warn "Missing: /usr/share/doc/csm/scripts/operations/pyscripts/start.py"
fi

# Slingshot fabric manager deep checks
if check_cmd kubectl; then
    log_shell_validate "slingshot_fmn_show_status" "Runtime:HEALTHY" "Ports in Error State:[[:space:]]*[1-9]" "Downed links:" "kubectl exec -i -n services \$(kubectl get pods -A | grep slingshot-fabric-manager | awk '{print \$2}' | head -1) -- fmn-show-status --detail"
    log_shell_validate "slingshot_linkdbg_fabric" "" "" "Action code|PROBLEM SYNOPSIS|unkn_port|downed links" "kubectl exec -i -n services \$(kubectl get pods -A | grep slingshot-fabric-manager | awk '{print \$2}' | head -1) -- linkdbg -L fabric"
    log_shell_validate "slingshot_linkdbg_edge" "" "" "Action code|PROBLEM SYNOPSIS|unkn_port|downed links" "kubectl exec -i -n services \$(kubectl get pods -A | grep slingshot-fabric-manager | awk '{print \$2}' | head -1) -- linkdbg -L edge"
    log_shell_validate "slingshot_show_flaps" "" "" "Showing [1-9][0-9]* links with a flap score" "kubectl exec -i -n services \$(kubectl get pods -A | grep slingshot-fabric-manager | awk '{print \$2}' | head -1) -- show-flaps"
fi

# Ceph deep checks
if check_cmd ceph; then
    log_cmd_validate "ceph_s" "HEALTH_" "HEALTH_ERR" "HEALTH_WARN" ceph -s
    log_cmd "ceph_osd_perf" ceph osd perf
    log_cmd "ceph_orch_ls" ceph orch ls
    log_cmd "ceph_orch_ps" ceph orch ps
    log_cmd "ceph_osd_tree" ceph osd tree
fi

# HMS discovery cronjob
if check_cmd kubectl; then
    log_cmd_validate "kubectl_get_cronjobs_hms_discovery" "False" "" "" kubectl get cronjobs -n services hms-discovery
fi

# Pod resource usage
if check_cmd kubectl; then
    log_cmd_validate "kubectl_top_pods_cpu_nocontainers" "" "" "metrics API not available|not found|Error from server" kubectl top pods -A --sort-by=cpu --containers=false
    log_cmd_validate "kubectl_top_pods_cpu_containers" "" "" "metrics API not available|not found|Error from server" kubectl top pods -A --sort-by=cpu --containers=true
    log_cmd_validate "kubectl_top_pods_mem_nocontainers" "" "" "metrics API not available|not found|Error from server" kubectl top pods -A --sort-by=memory --containers=false
    log_cmd_validate "kubectl_top_pods_mem_containers" "" "" "metrics API not available|not found|Error from server" kubectl top pods -A --sort-by=memory --containers=true
fi

# SAT status and inventory
if check_cmd sat; then
    log_cmd_validate "sat_status_ChassisBMC" "" "" "FAILED|Degraded" sat status --types ChassisBMC
    log_cmd_validate "sat_status_NodeBMC" "" "" "FAILED|Degraded" sat status --types NodeBMC
    log_cmd_validate "sat_status_ComputeModule" "" "" "FAILED|Degraded" sat status --types ComputeModule
    log_cmd_validate "sat_status_HSNBoard" "" "" "FAILED|Degraded" sat status --types HSNBoard
    log_cmd_validate "sat_status_NodeEnclosure" "" "" "FAILED|Degraded" sat status --types NodeEnclosure
    log_cmd_validate "sat_status_Chassis" "" "" "FAILED|Degraded" sat status --types Chassis
    log_cmd_validate "sat_status_Node" "" "" "FAILED|Degraded" sat status --types Node
    log_cmd_validate "sat_status_RouterBMC" "" "" "FAILED|Degraded" sat status --types RouterBMC
    log_cmd_validate "sat_status_RouterModule" "" "" "FAILED|Degraded" sat status --types RouterModule
    log_cmd "sat_showrev" sat showrev
    log_cmd "sat_firmware" sat firmware
    log_cmd "sat_hwinv" sat hwinv
    log_cmd "sat_hwmatch" sat hwmatch
    log_cmd "sat_slscheck" sat slscheck
    log_cmd "sat_status_compute_enabled_notready" sat status --filter role=compute --filter enabled=true --filter state!=ready
    log_cmd "sat_status_compute_enabled_off" sat status --filter role=compute --filter enabled=true --filter state=off
    log_cmd "sat_status_compute_enabled_on" sat status --filter role=compute --filter enabled=true --filter state=on
else
    print_warn "Missing: sat"
fi

# SLS dumpstate
if check_cmd cray; then
    log_shell "cray_sls_dumpstate" "cray sls dumpstate list --format json"
fi

# Crash dump inventory on NCNs
if check_cmd pdsh; then
    log_shell "pdsh_ls_var_crash" "pdsh -w ncn-m00[1-3],ncn-w0[01-30],ncn-s0[01-18] 'ls -l /var/crash' | dshbak -c"
fi

# Cassini NIC firmware (management nodes)
if check_cmd pdsh; then
    log_shell "pdsh_slingshot_firmware_query" "pdsh -w \$(kubectl get nodes | grep ncn-w | awk '{print \$1}' | xargs | sed 's/ /,/g') 'slingshot-firmware query' | dshbak -c"
fi

# SDU collections
if check_cmd pdsh; then
    log_shell "pdsh_sdu_list" "pdsh -w ncn-m00[1-3] 'ls -l /var/opt/cray/sdu' | dshbak -c"
    log_shell "pdsh_sdu_collection_local" "pdsh -w ncn-m00[1-3] 'ls -l /var/opt/cray/sdu/collection-local/triage/view' | dshbak -c"
    log_shell "pdsh_sdu_collection_mount" "pdsh -w ncn-m00[1-3] 'ls -l /var/opt/cray/sdu/collection-mount/triage/view' | dshbak -c"
fi

# SDU/RDA config snapshot
if check_cmd sdu; then
    log_cmd "sdu_conf" sdu bash cat /etc/opt/cray/sdu/sdu.conf
    log_cmd "rda_conf" sdu bash cat /etc/rda/rda.conf
    log_cmd "rda_acl" sdu bash cat /etc/rda/acl-rda.dat
    log_cmd "rda_hosts" sdu bash cat /etc/hosts
fi

# Namespace/pod resource limits
if check_cmd kubectl && check_cmd jq; then
    log_shell "namespace_resource_limits" "kubectl describe namespace"
    log_shell "pod_resource_limits" "kubectl get pod --all-namespaces --sort-by='.metadata.name' -o json | jq -r '[.items[] | {pod_name: .metadata.name, containers: .spec.containers[] | [ {container_name: .name, cpu_limits: .resources.limits.cpu, cpu_requested: .resources.requests.cpu, memory_limits: .resources.limits.memory, memory_requested: .resources.requests.memory} ] }]' | jq 'sort_by(.containers[0].cpu_requested)'"
fi

# OOM events
if check_cmd kubectl; then
    log_shell_validate "kubectl_oom_events" "" "OOM" "" "kubectl get events -A | grep -C3 OOM | grep -v rsyslog || true"
fi

# Describe nodes, allocated resources, conditions
if check_cmd kubectl; then
    log_shell "kubectl_describe_nodes" "for node in \$(kubectl get nodes | grep ncn | awk '{print \$1}'); do echo \$node; kubectl describe node \$node; done"
    log_shell "kubectl_allocated_resources" "for node in \$(kubectl get nodes | grep ncn | awk '{print \$1}'); do echo \$node; kubectl describe node \$node | grep Resource -A 6; done"
    log_shell "kubectl_node_conditions" "for node in \$(kubectl get nodes | grep ncn | awk '{print \$1}'); do echo \$node; kubectl describe node \$node | grep LastHeartbeatTime -A 8; done"
fi

# SMA AIOPS and alert health
if check_cmd kubectl; then
    log_cmd "sma_aiops_config" kubectl describe cm -n sma aiops-enable-disable-models
fi
if check_cmd cm; then
    log_cmd "cm_aiops_status" cm aiops status
    log_cmd "cm_aiops_trainer_status" cm aiops trainer status
    log_cmd "cm_health_alert_s" cm health alert -s
    log_cmd "cm_health_alert_query" cm health alert query
    log_cmd "cm_health_alertman_s" cm health alertman -s
    log_cmd "cm_health_alertman_compute" cm health alertman compute
    log_cmd "cm_health_alertman_fabric" cm health alertman fabric
    log_cmd "cm_health_alertman_prometheus" cm health alertman prometheus
    log_cmd "cm_health_alertman_slingshothsn" cm health alertman slingshothsn
    log_cmd "cm_health_alertman_slingshotswitch" cm health alertman slingshotswitch
    log_cmd "cm_health_alertman_aiops" cm health alertman aiops
    log_cmd "cm_health_alertman_crayalerts" cm health alertman crayalerts
    log_cmd "cm_health_alertman_cooldev" cm health alertman cooldev
    log_cmd "cm_health_alertman_query" cm health alertman query
fi

# BOS/CFS options
if check_cmd cray; then
    log_cmd "cray_bos_v2_options" cray bos v2 options list
    log_cmd "cray_cfs_options" cray cfs options list
    log_cmd "cray_cfs_v3_options" cray cfs v3 options list
fi

# CFS batcher config and logs
if check_cmd kubectl; then
    log_cmd "cfs_default_ansible_cfg" kubectl describe cm -n services cfs-default-ansible-cfg
    log_shell "cfs_sorted_pods" "kubectl -n services --sort-by=.metadata.creationTimestamp get pods | grep cfs"
    log_shell "cfs_successful_jobs" "kubectl get jobs -n services --field-selector status.successful=1 -l cfsversion --sort-by=.metadata.creationTimestamp"
    log_shell "cfs_batcher_logs" "kubectl logs -n services \$(kubectl get pods -o wide -n services | grep cray-cfs-batcher | awk '{print \$1}' | head -1)"
    log_shell "cfs_batch_pods_logs" "for i in \$(kubectl -n services --sort-by=.metadata.creationTimestamp get pods | grep cfs | grep -v Running | awk '{print \$1}'); do kubectl logs -n services --timestamps -c ansible \$i; done"
fi

# Nexus backup and space usage
if check_cmd kubectl; then
    log_cmd "nexus_pvc" kubectl get pvc -n nexus
    log_shell "nexus_df" "kubectl exec -n nexus deploy/nexus -c nexus -- df -Ph /nexus-data | grep '/nexus-data'"
    log_shell "nexus_df_summary" "kubectl exec -n nexus deploy/nexus -c nexus -- df -Ph /nexus-data | grep '/nexus-data' | awk '{print \"Used:\", \$3, \"Available:\", \$4, \"Total Size:\", \$2}'"
fi
if [ -x /usr/share/doc/csm/scripts/nexus-space-usage.sh ]; then
    log_cmd "nexus_space_usage" /usr/share/doc/csm/scripts/nexus-space-usage.sh
else
    print_warn "Missing: /usr/share/doc/csm/scripts/nexus-space-usage.sh"
fi

# etcd health (member list + endpoint)
if check_cmd pdsh; then
    log_shell "etcd_member_list" "pdsh -w ncn-m00[1-3] 'etcdctl --endpoints https://127.0.0.1:2379 --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt member list' | dshbak -c"
    log_shell "etcd_endpoint_health" "pdsh -w ncn-m00[1-3] 'etcdctl --endpoints https://127.0.0.1:2379 --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt endpoint health' | dshbak -c"
fi

# Certificate checks
if check_cmd kubectl && check_cmd jq && check_cmd openssl; then
    log_shell "cert_spire_intermediate" "kubectl get secret -n spire spire.spire.ca-tls -o json | jq -r '.data.\"tls.crt\" | @base64d' | openssl x509 -noout -enddate"
    log_shell "cert_kube_etcdbackup" "kubectl get secret -n kube-system kube-etcdbackup-etcd -o json | jq -r '.data.\"tls.crt\" | @base64d' | openssl x509 -noout -enddate"
    log_shell "cert_etcd_ca" "kubectl get secret -n sysmgmt-health etcd-client-cert -o json | jq -r '.data.\"etcd-ca\" | @base64d' | openssl x509 -noout -enddate"
    log_shell "cert_etcd_client" "kubectl get secret -n sysmgmt-health etcd-client-cert -o json | jq -r '.data.\"etcd-client\" | @base64d' | openssl x509 -noout -enddate"
fi

if check_cmd kubeadm; then
    log_cmd "kubeadm_cert_check" kubeadm certs check-expiration --config /etc/kubernetes/kubeadmcfg.yaml
fi

if check_cmd kubectl && check_cmd jq && check_cmd openssl; then
    log_shell "cert_sma_cluster_clients_ca" "kubectl -n sma get secret cluster-clients-ca-cert -o json | jq -r '.data.\"ca.crt\"' | base64 -d | openssl x509 -noout -enddate"
    log_shell "cert_sma_timescaledb" "kubectl -n sma get secret sma-timescaledb-single-certificate -o json | jq -r '.data.\"tls.crt\"' | base64 -d | openssl x509 -noout -enddate"
    log_shell "cert_sma_cluster_operator" "kubectl -n sma get secret cluster-cluster-operator-certs -o json | jq -r '.data.\"cluster-operator.crt\"' | base64 -d | openssl x509 -noout -enddate"
    log_shell "cert_sma_kafka_exporter" "kubectl -n sma get secret cluster-kafka-exporter-certs -o json | jq -r '.data.\"kafka-exporter.crt\"' | base64 -d | openssl x509 -noout -enddate"
    log_shell "cert_sma_entity_operator" "kubectl -n sma get secret cluster-entity-topic-operator-certs -o json | jq -r '.data.\"entity-operator.crt\"' | base64 -d | openssl x509 -noout -enddate"
fi

# Spire certs (pre-1.7)
if check_cmd kubectl; then
    log_shell "cert_spire_tokens_tls" "kubectl describe certificate -n spire spire-tokens-tls | egrep 'Not Before|Not After|Renewal Time'"
fi

# OAuth2 proxy certs
if check_cmd kubectl; then
    log_shell "cert_cray_oauth2_proxies" "kubectl -n services get certificate cray-oauth2-proxies-customer-management -o yaml | egrep 'notAfter|notBefore|renewalTime'; kubectl -n services get certificate cray-oauth2-proxies-customer-high-speed -o yaml | egrep 'notAfter|notBefore|renewalTime'; kubectl -n services get certificate cray-oauth2-proxies-customer-access -o yaml | egrep 'notAfter|notBefore|renewalTime'"
fi

# Weave status (CSM 1.6 and earlier)
if check_cmd pdsh; then
    log_shell "weave_status" "pdsh -w ncn-m00[1-3] weave --local status connections | dshbak -c"
fi

# Node filesystem usage
if check_cmd pdsh; then
    log_shell "df_containerd" "pdsh -w \$(kubectl get nodes | grep ncn | awk '{print \$1}' | xargs | sed 's/ /,/g') df -h /var/lib/containerd | dshbak -c"
    log_shell "df_kubelet" "pdsh -w \$(kubectl get nodes | grep ncn | awk '{print \$1}' | xargs | sed 's/ /,/g') df -h /var/lib/kubelet | dshbak -c"
    log_shell "df_s3fs_cache" "pdsh -w \$(kubectl get nodes | grep ncn | awk '{print \$1}' | xargs | sed 's/ /,/g') df -h /var/lib/s3fs_cache | dshbak -c"
    log_shell "df_root" "pdsh -w \$(kubectl get nodes | grep ncn | awk '{print \$1}' | xargs | sed 's/ /,/g') df -h / | dshbak -c"
fi

# crictl NotReady pods
if check_cmd pdsh && check_cmd jq; then
    log_shell "crictl_pods_notready" "pdsh -w \$(kubectl get nodes | grep ncn | awk '{print \$1}' | xargs | sed 's/ /,/g') 'crictl pods -state NotReady -o json | jq -r \\\".items[].id\\\" | wc -l' | sort"
fi

# Spire entry counts
if check_cmd kubectl; then
    log_shell "spire_entry_count" "kubectl exec -i -n spire cray-spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry count"
    log_shell "spire_entry_count_list" "kubectl exec -i -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry show | grep 'Entry ID' | wc -l"
fi

# NCN health checks
if [ -x /opt/cray/platform-utils/ncnHealthChecks.sh ]; then
    log_cmd "ncnHealthChecks_all" /opt/cray/platform-utils/ncnHealthChecks.sh
    log_cmd "ncnHealthChecks_ncn_uptimes" /opt/cray/platform-utils/ncnHealthChecks.sh -s ncn_uptimes
    log_cmd "ncnHealthChecks_node_resource_consumption" /opt/cray/platform-utils/ncnHealthChecks.sh -s node_resource_consumption
    log_cmd "ncnHealthChecks_pods_not_running" /opt/cray/platform-utils/ncnHealthChecks.sh -s pods_not_running
else
    print_warn "Missing: /opt/cray/platform-utils/ncnHealthChecks.sh"
fi

if [ -x /opt/cray/platform-utils/ncnPostgresHealthChecks.sh ]; then
    log_cmd "ncnPostgresHealthChecks" /opt/cray/platform-utils/ncnPostgresHealthChecks.sh
else
    print_warn "Missing: /opt/cray/platform-utils/ncnPostgresHealthChecks.sh"
fi

if [ -x /opt/cray/tests/install/ncn/automated/ncn-postgres-tests ]; then
    log_cmd "ncn_postgres_tests" /opt/cray/tests/install/ncn/automated/ncn-postgres-tests
else
    print_warn "Missing: /opt/cray/tests/install/ncn/automated/ncn-postgres-tests"
fi

if [ -x /opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck ]; then
    if [ -z "$SW_ADMIN_PASSWORD" ]; then
        print_warn "SW_ADMIN_PASSWORD not set; ncn-k8s-combined-healthcheck may require switch admin password"
    fi
    log_cmd "ncn_k8s_combined_healthcheck" /opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck
else
    print_warn "Missing: /opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck"
fi

# Cluster-wide pod inventory
if check_cmd kubectl; then
    log_cmd "kubectl_get_pods_wide" kubectl get pods -o wide -A
fi

print_info "Extended pre-upgrade checks completed at $(date)"
print_summary
print_info "Logs saved under: $LOG_BASE"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
fi
