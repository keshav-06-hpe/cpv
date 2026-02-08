#!/bin/bash
################################################################################
# CSM Install/Upgrade Prechecks (Read-Only)
# Purpose: Validate readiness for CSM install or upgrade (1.6.x -> 1.7.x)
# Docs:
#   https://github.com/Cray-HPE/docs-csm/
#   https://github.com/Cray-HPE/hpe-csm-scripts/
################################################################################

set -o pipefail

# -------- Settings --------
LOG_DIR="/etc/cray/upgrade/csm/pre-checks"
RUN_ID="prechecks_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/${RUN_ID}.log"
MODE="pre-upgrade"   # pre-install or pre-upgrade

# -------- Colors --------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------- Counters --------
TOTAL=0
PASS=0
FAIL=0
WARN=0

# -------- Helpers --------
mkdir -p "${LOG_DIR}" || true

ts() { date '+%Y-%m-%d %H:%M:%S'; }

log() { echo -e "$*" | tee -a "${LOG_FILE}"; }

header() {
	log "\n${BLUE}========================================${NC}"
	log "${BLUE}$1${NC}"
	log "${BLUE}========================================${NC}"
}

check_start() {
	TOTAL=$((TOTAL+1))
	log "\n[CHECK ${TOTAL}] $1"
}

pass() { PASS=$((PASS+1)); log "${GREEN}✓ PASS${NC}: $1"; }
fail() { FAIL=$((FAIL+1)); log "${RED}✗ FAIL${NC}: $1"; }
warn() { WARN=$((WARN+1)); log "${YELLOW}⚠ WARNING${NC}: $1"; }
info() { log "${BLUE}ℹ INFO${NC}: $1"; }

has_cmd() { command -v "$1" &>/dev/null; }

run_cmd() {
	local label="$1"; shift
	log "[RUN] $*"
	"$@" 2>&1 | tee -a "${LOG_FILE}"
	local rc=${PIPESTATUS[0]}
	if [ $rc -eq 0 ]; then
		pass "$label"
	else
		fail "$label (exit ${rc})"
	fi
}

run_shell() {
	local label="$1"; local cmd="$2"
	log "[RUN] $cmd"
	bash -c "set -o pipefail; ${cmd}" 2>&1 | tee -a "${LOG_FILE}"
	local rc=${PIPESTATUS[0]}
	if [ $rc -eq 0 ]; then
		pass "$label"
	else
		fail "$label (exit ${rc})"
	fi
}

usage() {
	cat <<EOF
Usage: $(basename "$0") [-m pre-install|pre-upgrade] [-h]

Notes:
	- Read-only checks for CSM install/upgrade readiness
	- Logs: ${LOG_DIR}
EOF
}

# -------- Parse args --------
while getopts "hm:" opt; do
	case "${opt}" in
		h) usage; exit 0 ;;
		m)
			if [[ "${OPTARG}" == "pre-install" || "${OPTARG}" == "pre-upgrade" ]]; then
				MODE="${OPTARG}"
			else
				echo "Invalid mode: ${OPTARG}"; usage; exit 2
			fi
			;;
		*) usage; exit 2 ;;
	esac
done

log "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
log "${BLUE}║  CSM Prechecks (Read-Only)                                    ║${NC}"
log "${BLUE}║  Mode: ${MODE}                                                ║${NC}"
log "${BLUE}║  Date: $(date)                                    ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
info "Logs: ${LOG_FILE}"

# -------- Checks --------
header "System Prerequisites"
check_start "Required commands"
for c in kubectl helm jq cray iuf; do
	if has_cmd "$c"; then
		pass "$c present"
	else
		warn "$c not found (some checks will be skipped)"
	fi
done

check_start "Kubernetes node readiness"
if has_cmd kubectl; then
	NOT_READY=$(kubectl get nodes 2>/dev/null | grep -v Ready | grep -v NAME | wc -l)
	if [ "$NOT_READY" -gt 0 ]; then
		fail "Some nodes are NotReady"
		kubectl get nodes | grep -v Ready | grep -v NAME | tee -a "${LOG_FILE}"
	else
		pass "All nodes Ready"
	fi
else
	warn "kubectl not available"
fi

check_start "Critical namespaces pods"
if has_cmd kubectl; then
	CRITICAL_NS="kube-system services nexus vault"
	for ns in $CRITICAL_NS; do
		PROBLEM=$(kubectl get pods -n "$ns" 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
		if [ "$PROBLEM" -gt 0 ]; then
			warn "Pods not healthy in $ns"
			kubectl get pods -n "$ns" | grep -v Running | grep -v Completed | tee -a "${LOG_FILE}"
		fi
	done
	pass "Critical namespace scan completed"
fi

check_start "PVC status"
if has_cmd kubectl; then
	PENDING=$(kubectl get pvc -A 2>/dev/null | grep -v Bound | grep -v STATUS | wc -l)
	if [ "$PENDING" -gt 0 ]; then
		fail "PVCs not Bound"
		kubectl get pvc -A | grep -v Bound | grep -v STATUS | tee -a "${LOG_FILE}"
	else
		pass "All PVCs Bound"
	fi
fi

header "CSM / IUF"
check_start "Active IUF sessions"
if has_cmd iuf; then
	ACTIVE=$(iuf list 2>/dev/null | grep -v Completed | wc -l)
	if [ "$ACTIVE" -gt 0 ]; then
		fail "Active IUF sessions detected"
		iuf list | tee -a "${LOG_FILE}"
	else
		pass "No active IUF sessions"
	fi
else
	warn "iuf not available"
fi

check_start "Running BOS sessions"
if has_cmd cray; then
	BOS=$(cray bos v2 sessions list --format json 2>/dev/null | jq -r '.sessions[]?.status' | grep -v completed | wc -l)
	if [ "$BOS" -gt 0 ]; then
		warn "Running BOS sessions detected"
		cray bos v2 sessions list | tee -a "${LOG_FILE}"
	else
		pass "No running BOS sessions"
	fi
fi

check_start "Running CFS sessions"
if has_cmd cray; then
	CFS=$(cray cfs v3 sessions list --format json 2>/dev/null | jq -r '.sessions[]?.status' | grep -v completed | wc -l)
	if [ "$CFS" -gt 0 ]; then
		warn "Running CFS sessions detected"
		cray cfs v3 sessions list | tee -a "${LOG_FILE}"
	else
		pass "No running CFS sessions"
	fi
fi

header "Storage / Nexus"
check_start "Ceph health"
if has_cmd ceph; then
	HEALTH=$(ceph health 2>/dev/null | awk '{print $1}')
	case "$HEALTH" in
		HEALTH_OK) pass "Ceph health OK" ;;
		HEALTH_WARN) warn "Ceph health WARN" ;;
		HEALTH_ERR|HEALTH_CRIT) fail "Ceph health ERROR" ;;
		*) warn "Unknown Ceph health state" ;;
	esac
else
	warn "ceph not available"
fi

check_start "Nexus PVC usage"
if has_cmd kubectl; then
	run_shell "Nexus PVC list" "kubectl get pvc -n nexus"
	run_shell "Nexus data usage" "kubectl exec -n nexus deploy/nexus -c nexus -- df -Ph /nexus-data | grep '/nexus-data'"
fi

header "Kubernetes / CNI"
check_start "Weave to Cilium migration readiness"
if has_cmd kubectl; then
	WEAVE=$(kubectl get pods -n kube-system 2>/dev/null | grep -c weave)
	if [ "$WEAVE" -gt 0 ]; then
		warn "Weave detected; verify Cilium migration prerequisites"
		info "Ensure BSS global metadata has k8s_primary_cni set"
	else
		pass "Weave not detected"
	fi
fi

check_start "etcd pod health"
if has_cmd kubectl; then
	ETCD=$(kubectl get pods -n kube-system 2>/dev/null | grep etcd | grep Running | wc -l)
	if [ "$ETCD" -lt 3 ]; then
		fail "etcd pods not healthy"
		kubectl get pods -n kube-system | grep etcd | tee -a "${LOG_FILE}"
	else
		pass "etcd pods healthy"
	fi
fi

header "Security / Certs"
check_start "Kubernetes cert expiration"
if [ -f "/etc/kubernetes/pki/apiserver.crt" ] && has_cmd openssl; then
	EXP=$(openssl x509 -enddate -noout -in /etc/kubernetes/pki/apiserver.crt | cut -d= -f2)
	info "apiserver.crt expires: ${EXP}"
	pass "Certificate read"
else
	warn "apiserver.crt not readable or openssl missing"
fi

header "HMS / Spire"
check_start "Spire pods"
if has_cmd kubectl; then
	SPIRE_BAD=$(kubectl get pods -n spire 2>/dev/null | grep spire-server | grep -v Running | wc -l)
	if [ "$SPIRE_BAD" -gt 0 ]; then
		fail "Spire server pods not healthy"
		kubectl get pods -n spire | tee -a "${LOG_FILE}"
	else
		pass "Spire server pods healthy"
	fi
fi

check_start "HMS discovery service"
if has_cmd kubectl; then
	HMS_DISC=$(kubectl get pods -n services 2>/dev/null | grep cray-hms-discovery | grep Running | wc -l)
	if [ "$HMS_DISC" -eq 0 ]; then
		warn "HMS discovery not running"
		kubectl get pods -n services | grep cray-hms-discovery | tee -a "${LOG_FILE}"
	else
		pass "HMS discovery running"
	fi
fi

header "SMA / USS"
check_start "OpenSearch pods"
if has_cmd kubectl; then
	OS_BAD=$(kubectl get pods -n sma 2>/dev/null | grep opensearch-master | grep -v Running | wc -l)
	if [ "$OS_BAD" -gt 0 ]; then
		warn "OpenSearch pods not healthy"
		kubectl get pods -n sma | grep opensearch-master | tee -a "${LOG_FILE}"
	else
		pass "OpenSearch pods healthy"
	fi
fi

check_start "Kafka topics (telemetry)"
if has_cmd kubectl; then
	if kubectl get pods -n sma 2>/dev/null | grep -q cluster-kafka-0; then
		TOPIC=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep -c cray-telemetry-metric)
		if [ "$TOPIC" -eq 0 ]; then
			warn "Missing cray-telemetry-metric topic (see SMA troubleshooting)"
		else
			pass "Telemetry topics appear present"
		fi
	else
		warn "Kafka pod not found in sma namespace"
	fi
fi

header "Summary"
log "\nTotal Checks: $TOTAL"
log "${GREEN}Passed: $PASS${NC}"
log "${YELLOW}Warnings: $WARN${NC}"
log "${RED}Failed: $FAIL${NC}"
log "\nLog file: ${LOG_FILE}"

if [ "$FAIL" -gt 0 ]; then
	exit 1
elif [ "$WARN" -gt 0 ]; then
	exit 2
else
	exit 0
fi
