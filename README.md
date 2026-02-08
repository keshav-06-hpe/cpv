# CSM Pre-Install & Pre-Upgrade Checks

Read-only bash scripts to validate system readiness for CSM 25.3.2 (1.6.2) → 25.9.0 (1.7.0). These checks surface known issues before preparation or upgrade and write detailed logs for documentation and troubleshooting.

## Repository contents

| Script | Purpose |
| --- | --- |
| `pre_install_checks.sh` | Pre-install validation run before the preparation phase. |
| `pre_upgrade_checks.sh` | Main pre-upgrade validation for known issues. |
| `pre_upgrade_extended_checks.sh` | Extended checks beyond the base pre-upgrade set. |
| `csm_prechecks.sh` | Convenience wrapper/alternate entry point for the precheck suite. |

Supporting documentation:
- [PRE_UPGRADE_CHECKS_README.md](PRE_UPGRADE_CHECKS_README.md)
- [PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md](PRE_UPGRADE_SCRIPT_ENHANCEMENT_GUIDE.md)
- [CSM_Upgrade_25.3.2_to_25.9.0_Summary.md](CSM_Upgrade_25.3.2_to_25.9.0_Summary.md)

## Requirements

- Bash shell
- Tools used by the checks (as available): `kubectl`, `helm`, `cray`, `iuf`, `vault`, `nexus` utilities
- Recommended to run on the management node with appropriate privileges

Missing commands are handled gracefully with warnings.

## Quick start

```bash
chmod +x pre_upgrade_checks.sh
./pre_upgrade_checks.sh
```

Run pre-install checks:

```bash
chmod +x pre_install_checks.sh
./pre_install_checks.sh
```

## Modes

`pre_upgrade_checks.sh` supports a mode flag:

```bash
./pre_upgrade_checks.sh -m pre-install
./pre_upgrade_checks.sh -m pre-upgrade
```

## Output and logs

- Color-coded console output: PASS / WARNING / FAIL / INFO
- Logs saved to:
  - `/etc/cray/upgrade/csm/pre-checks/pre_upgrade_checks_YYYYMMDD_HHMMSS.log`

## Exit codes

- `0` — All checks passed
- `1` — One or more critical failures
- `2` — Warnings present

## Typical workflow

1. Run before preparation (Phase 1)
2. Run again after preparation, before IUF (Phase 2)
3. Re-run after fixing any issues

## Troubleshooting

- Ensure scripts are executable.
- Verify required commands are in `PATH`.
- If the log directory can’t be created, create it manually or adjust `LOG_DIR` in the script.

## Contributing

- Keep checks read-only.
- Add new checks using the helper functions (see the enhancement guide).
- Prefer minimal, targeted changes with clear logging.
