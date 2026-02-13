#!/bin/bash
################################################################################
# CSM Pre-Install Check Wrapper
# Purpose: Run read-only pre-install checks using pre_upgrade_checks.sh
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/pre_upgrade_checks.sh"

if [ ! -x "$CHECK_SCRIPT" ]; then
    echo "ERROR: pre_upgrade_checks.sh not found or not executable at: $CHECK_SCRIPT"
    exit 1
fi

exec "$CHECK_SCRIPT" -m pre-install "$@"
