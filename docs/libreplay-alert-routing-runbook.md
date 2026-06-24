# LibrePlay Alert Routing Runbook

Status: `PROD-OBS-ALERT-SLO-05` safe slice.

## Scope

LibrePlay alert routing currently uses the shared VictoriaMetrics Alertmanager
stack. `severity=warn` and `severity=critical` LibrePlay alerts resolve to the
shared Synapse Alertmanager receiver for visibility. This is not a dedicated
LibrePlay pager.

The dedicated LibrePlay receiver or pager remains a cross-tenant follow-up. It
requires an approved destination and an observability-owner change to shared
Alertmanager routing.

External error tracking is not active for LibrePlay yet. The application keeps a
fail-closed no-op posture until a provider and secret are approved.

## Read-only Rehearsal

Run the checker from the GitOps repo:

```sh
scripts/check-libreplay-alert-routing.sh
```

The checker first runs the synthetics/SLO contract gate, then resolves each
LibrePlay SLO label set with `amtool config routes test` inside the live
Alertmanager pod. This does not create alerts, silences, routes, or receiver
changes.

Expected result today:

- `LibrePlaySyntheticAvailabilityBudgetLow` with `severity=warn` resolves to a
  non-blackhole receiver.
- `LibrePlaySLOErrorBudgetBurnFast` with `severity=critical` resolves to a
  non-blackhole receiver.
- `LibrePlaySLOErrorBudgetBurnMedium` with `severity=critical` resolves to a
  non-blackhole receiver.
- `LibrePlaySLOErrorBudgetBurnSlow` with `severity=warn` resolves to a
  non-blackhole receiver.

Today that receiver is expected to be the shared Synapse Alertmanager receiver.
If the receiver changes to a dedicated LibrePlay receiver later, the checker may
still pass as long as the result is not a blackhole.

## Failure Handling

If any label set resolves to a blackhole receiver:

1. Check whether a rule introduced `severity=warning`. LibrePlay rules must use
   `severity=warn` or `severity=critical`.
2. Keep shared Alertmanager config unchanged unless the observability owner has
   approved a cross-tenant routing change.
3. Re-run `scripts/check-libreplay-synthetics-contract.sh` and the routing
   checker before deploying.

If the checker reports cluster connectivity as blocked, do not treat routing as
validated. Re-run from a host with access to the monitoring namespace.

## Manual Fire Rehearsal

Manual fire rehearsal is not part of CI or the automated checker.

Before a real fire rehearsal:

1. Get explicit owner approval for the maintenance window and target alert.
2. Announce that the alert will reach the shared Synapse receiver.
3. Choose one reversible test path and document rollback before starting.
4. Time-box the test and record start/end time, receiver evidence, and cleanup.

Acceptable approaches include a temporary, owner-approved synthetic-probe test or
an explicitly test-labelled Alertmanager injection approved by the observability
owner. Roll back immediately after receiver evidence is captured, then confirm
the alert clears and no silence or test state remains.

Do not automate this real-fire step until LibrePlay has a dedicated receiver and
the observability owner approves the procedure.
