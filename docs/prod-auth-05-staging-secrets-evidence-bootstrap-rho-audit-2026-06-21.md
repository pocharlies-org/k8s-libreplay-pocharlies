# PROD-AUTH-05 Staging Secrets Evidence Bootstrap RHO Audit

Date: 2026-06-21
Owner: PMO / DevOps / Security
Status: `IMPLEMENTED-BLOCKED-BY-REAL-PROVIDER-SECRETS`

## Objective

Strengthen the safe path from provider evidence to Vault `secret/libreplay/staging`
without printing or inventing secret values. This gate prepares the real-auth
staging rollout, but it does not approve runtime staging until real Google,
Meta, SMTP and mailbox inputs exist.

## Directives

- [x] Do not print secret values. Evidence: scripts only print evidence status,
  public callback expectations and key names.
- [x] Do not manually create Kubernetes Secrets. Evidence: source of truth
  remains Vault through `ExternalSecret/libreplay-secrets`.
- [x] Do not repoint Argo to `staging/overlays/runtime`. Evidence:
  `libreplay-staging` remains contract-only while Vault data is absent.
- [x] Keep provider evidence separate from provider secret values. Evidence:
  `scripts/check-libreplay-staging-secret-evidence.sh` validates metadata only.

## Acceptance Criteria

- [x] Non-secret evidence preflight exists. Evidence:
  `scripts/check-libreplay-staging-secret-evidence.sh`.
- [x] Evidence preflight checks exact Google and Facebook staging callback URIs.
  Evidence: required env vars
  `LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI` and
  `LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI`.
- [x] Evidence preflight checks SMTP sender identity without credentials.
  Evidence: required env var `LIBREPLAY_STAGING_SMTP_MAIL_FROM` must equal
  `LibrePlay <noreply@libreplay.e-dani.com>`.
- [x] Full evidence preflight checks controlled mailbox shape and
  plus-addressing/catch-all acknowledgement. Evidence:
  `LIBREPLAY_STAGING_AUTH_EMAIL` and
  `LIBREPLAY_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1`.
- [x] Vault bootstrap refuses write mode unless provider evidence metadata is
  present. Evidence: `scripts/bootstrap-libreplay-staging-secrets.sh --write`
  calls `scripts/check-libreplay-staging-secret-evidence.sh --strict --vault-write`
  before `vault kv put`.
- [x] Bootstrap SMTP validation matches staging config. Evidence: bootstrap
  requires `SMTP_PORT=465` while staging config has `SMTP_SECURE=true`, and
  rejects placeholder/local SMTP hosts.
- [x] Docs avoid examples that print secret values. Evidence:
  staging/production intake docs list Secret key names with go-template instead
  of dumping `.data`.
- [x] Staging runbook lists all 19 key names. Evidence:
  `METRICS_BEARER_TOKEN` is included in the required key inventory.
- [x] Source app config rejects placeholder staging/prod provider posture.
  Evidence: source `packages/config/src/env.ts` now rejects local/LAN/example
  URLs, malformed Google/Meta IDs, placeholder provider secrets, missing SMTP
  auth and missing `SMTP_SECURE=true` in staging/production.
- [x] Source GitHub workflow requires mailbox delivery confirmation. Evidence:
  `.github/workflows/staging-real-auth.yml` reads
  `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED` and validates it equals `1`.
- [blocked] Vault record exists and preflight is strict-green. Blocker:
  approved real provider values and evidence have not been supplied.

## Specialist Checks

- [x] DevOps/Staging subagent pass completed read-only. Evidence: Boole
  confirmed contract/static/runtime checks pass, `harbor-pull`, DNS and TLS are
  OK, and the only strict preflight blockers are missing
  `ExternalSecret/libreplay-secrets` provider data and absent materialized
  Secret.
- [x] Security/Auth subagent pass completed read-only. Evidence: Euclid
  confirmed 19-key contract alignment, mock-disabled staging posture, OAuth
  state/PKCE/nonce guardrails, SMTP console blocking, GitHub environment
  protection and the remaining provider/Vault/mailbox blockers.

## Verification Commands

- [x] `bash -n scripts/check-libreplay-staging-secret-evidence.sh`
- [x] `bash -n scripts/bootstrap-libreplay-staging-secrets.sh`
- [x] Evidence preflight report mode with missing env returns blockers without
  printing values.
- [x] Evidence preflight strict mode fails closed with missing env.
- [x] Evidence preflight strict mode passes with synthetic non-secret evidence.
- [x] Bootstrap dry-run passes with synthetic provider-shaped values and evidence.
- [x] Bootstrap dry-run rejects placeholder-like provider secrets. Evidence:
  `GOOGLE_CLIENT_SECRET=fake ... --dry-run` fails before any Vault write.
- [x] Static staging contract/runtime/preflight behavior remains unchanged.
  Evidence: static contract and runtime checks pass; live preflight remains
  blocked only by `ExternalSecret/libreplay-secrets` and missing materialized
  Secret.
- [x] Source config guardrails pass. Evidence:
  `pnpm --filter @libreplay/config test -- src/__tests__/env.test.ts` returned
  `24 passed`; `pnpm --filter @libreplay/config typecheck` passed.
- [blocked] Source GitHub preflight strict mode blocks on the expected missing
  environment secrets. Evidence: it reports missing `PW_STAGING_AUTH_EMAIL` and
  `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED`.
- [x] `git diff --check` passed in source and GitOps.

## Residual Blockers

- [blocked] Add approved Google OAuth app values and callback evidence for
  `https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback`.
- [blocked] Add approved Meta/Facebook app values and callback evidence for
  `https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback`.
- [blocked] Add approved SMTP credentials and sender/domain evidence for
  `LibrePlay <noreply@libreplay.e-dani.com>`.
- [blocked] Add controlled plus-addressable/catch-all mailbox as GitHub
  environment secrets `PW_STAGING_AUTH_EMAIL` and
  `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1`.
- [blocked] Write Vault `secret/libreplay/staging`, sync ESO and run
  `scripts/check-libreplay-staging-preflight.sh --strict`.
