# Billing Agent Validation

Date: 2026-02-20  
Scope: runner-side UBB reporting contract and idempotence for Marketplace billing.

## Billing Contract Under Test

- Plan ID: `gbx_target_diligence_core`
- Standard metric: `standard_audit_run`
- Deep metric: `deep_audit_run`
- One metric per run, selected by run mode
- Invalid metric/mode or plan ID fails fast

## Test Method

- Exercised `app/gbx_core_runner_v3.py::_report_usage_once(...)` with controlled `run_manifest.json` inputs.
- Monkeypatched `_post_json` to capture outbound usage payloads without requiring live Service Control.
- Verified post-run manifest metadata (`ubbagent_metric`, `ubbagent_run_mode`, idempotence flags).
- Verified completion-only guard (`terminal_state=COMPLETED_SUCCESS`) before usage emission.

## Results

1. `standard_reports_once` -> PASS

- Input: `GBX_RUN_MODE=standard`, plan_id=`gbx_target_diligence_core`
- Expected: one report with `standard_audit_run`
- Observed: one report, metric `standard_audit_run`

2. `deep_reports_once` -> PASS

- Input: `GBX_RUN_MODE=deep`, plan_id=`gbx_target_diligence_core`
- Expected: one report with `deep_audit_run`
- Observed: one report, metric `deep_audit_run`

3. `idempotent_same_run_id_no_second_report` -> PASS

- Input: manifest already contains `ubbagent_reported=true` for same `run_id`
- Expected: no second report
- Observed: zero report calls

4. `misconfig_metric_override_fails` -> PASS

- Input: `GBX_RUN_MODE=standard`, `UBB_METRIC_NAME=deep_audit_run`
- Expected: hard fail before report
- Observed: raised `Billing metric mismatch for run_mode='standard'...`

5. `bad_plan_id_fails` -> PASS

- Input: plan_id=`gbx_target_diligence_core_deep`
- Expected: hard fail before report
- Observed: raised `Unsupported entitlement plan_id(s)... Expected only 'gbx_target_diligence_core'.`

## Runtime Log Confirmation

The runner now logs the enforced contract at report time:

- `Billing contract: run_mode=standard metric=standard_audit_run plan_id=gbx_target_diligence_core`
- `Billing contract: run_mode=deep metric=deep_audit_run plan_id=gbx_target_diligence_core`

## Notes

- This validation covers deterministic runner-side contract enforcement and emission logic.
- For final go-live evidence, run one Standard and one Deep deployment with UBB sidecar enabled and confirm:
  - `run_manifest.json` contains the expected `ubbagent_metric`
  - Marketplace telemetry receives exactly one matching metric event per run
