# LibrePlay Log Aggregation Policy

Status: `PROD-OBS-ALERT-SLO-05` policy artifact for the already-live sink.

## Sink

LibrePlay stdout/stderr logs are aggregated by the shared Grafana Alloy
DaemonSet into Loki through the monitoring stack. Use namespace labels as the
primary selectors:

- Production: `namespace="libreplay"`
- Staging: `namespace="libreplay-staging"`

The policy covers aggregation posture and operator checks. It does not activate
external error tracking.

## Retention

Retention is 336h, equal to 14 days. This was confirmed in the
`PROD-OBS-ALERT-SLO-05` Security pass from the live Loki configuration.

Do not copy the Loki ConfigMap into this repository or into reports. The
Security pass found a pre-existing observability-stack issue: object-store
credentials are present in `monitoring/configmap/loki`. That finding is
out-of-scope for LibrePlay and must be handled by the observability owner; no
credential values should be reproduced in LibrePlay docs, scripts, or tickets.

## Safe Checks

Automation may use Loki label-index endpoints to confirm that LibrePlay streams
exist, for example by checking that the namespace label includes `libreplay` or
`libreplay-staging`.

Automation must not dump log content, include real log samples in CI output, or
copy shared Loki configuration. Log lines can contain request metadata, user
data, or transient integration details even when upstream redaction is enabled.

## Redaction Posture

LibrePlay source-side structured logging already carries the redaction and
request-correlation posture. The log sink should be treated as an aggregation
transport, not as the place to redact secrets or user data after emission.

Operational expectations:

- Keep sensitive values out of application logs at source.
- Prefer request IDs, dependency names, queue names, and status codes over raw
  payloads.
- Use narrow selectors and time windows during manual investigation.
- Avoid pasting raw log lines into tickets unless they have been reviewed and
  sanitized.

## External Error Tracking

External error tracking is not active for LibrePlay. Provider choice, secrets,
and staging smoke evidence remain required before Sentry, GlitchTip, or another
tracker can be declared live.

Until then, the supported production signals are:

- Runtime metrics and VMRule alerts.
- LAN synthetic SLO alerts.
- Aggregated logs in Loki through Alloy.
- Application request IDs for correlation.
