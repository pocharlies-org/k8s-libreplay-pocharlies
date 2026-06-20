# PROD-OPS-04 Production Contract RHO Audit

Date: 2026-06-20
Owner: PMO / DevOps / Security
Status: `IMPLEMENTED-CONTRACT-ONLY-BLOCKED-BY-PROVIDERS`

## Objective

Create a production-only static contract so LibrePlay has a concrete,
fail-closed production environment definition without exposing real users or
deploying runtime workloads.

## Directives

- [x] Do not activate production runtime. Evidence: `production/` renders only
  Namespace, ExternalSecrets, DNS preflight Service and ConfigMap.
- [x] Keep production separate from LAN and staging. Evidence: namespace
  `libreplay-production`, Vault path `secret/libreplay/production`, host
  `https://libreplay.e-dani.com`.
- [x] Keep payment fail-closed until an approved PSP exists. Evidence:
  `PAYMENT_PROVIDER=disabled` and `ENABLE_MOCK_PAYMENTS=false`.
- [x] Disable all source-level production mocks. Evidence: production ConfigMap
  sets every `ENABLE_MOCK_*` flag to `false`.
- [x] Do not print or commit secrets. Evidence: only key names are declared.

## Acceptance Criteria

- [x] Static production Kustomize path exists. Evidence:
  `production/kustomization.yaml`.
- [x] Production contract declares explicit required secret keys. Evidence:
  `production/libreplay-production-contract.yaml` uses explicit
  `ExternalSecret.spec.data` entries for the same provider/internal key names as
  staging, all under `secret/libreplay/production`.
- [x] Production config is fail-closed. Evidence: `DEPLOYMENT_MODE=production`,
  `USE_MOCK_OAUTH=false`, `AUTH_EMAIL_PROVIDER=smtp`,
  `PAYMENT_PROVIDER=disabled`, all mock flags `false`, Redis fail-closed rate
  limiting, and Cloudflare client IP trust.
- [x] Public production host and media URL are non-LAN HTTPS URLs. Evidence:
  `APP_BASE_URL=https://libreplay.e-dani.com` and
  `MINIO_PUBLIC_URL=https://media.libreplay.e-dani.com`.
- [x] Checker rejects LAN/staging drift and workload activation. Evidence:
  `scripts/check-libreplay-production-contract.sh`.
- [x] Production secret intake exists. Evidence:
  `docs/libreplay-production-secrets-intake.md`.
- [x] GitOps CI renders and scans the production contract. Evidence:
  `.github/workflows/ci.yml` includes `production` in `kustomize_paths` and
  the no-`:latest` image grep scope.
- [blocked] Production runtime is live and validated. Blocker: real provider
  credentials, PSP, CDN/media policy, identity/CSAM/media moderation providers,
  HA/backup/DR and compliance gates are not closed.

## Verification Commands

- [x] `scripts/check-libreplay-production-contract.sh` passed.
- [x] `kubectl apply --dry-run=client -k production` passed.
- [x] `kubectl kustomize production` rendered Namespace, ConfigMap, DNS
  preflight Service and ExternalSecrets only: 207 rendered lines.
- [x] Anti-drift grep found no production render matches for workloads,
  LAN/staging deployment modes, true mock flags, mock payments, `dataFrom`, or
  staging/LAN Vault paths. Evidence: `rg` returned no matches.
- [x] `sh -n scripts/check-libreplay-production-contract.sh` passed.
- [x] `git diff --check` passed.

## Specialist Checks

- [x] DevOps/Security subagent checklist reconciled. Evidence: Pauli confirmed
  there was no prior production overlay and recommended namespace
  `libreplay-production`, Vault path `secret/libreplay/production`,
  `PAYMENT_PROVIDER=disabled`, all mocks false, Cloudflare production edge
  posture and separate production checks.
- [x] PMO final verification checklist reconciled.
