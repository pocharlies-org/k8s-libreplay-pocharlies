# LibrePlay Staging Secrets Intake

Owner: PMO / DevOps / Security
Date: 2026-06-21

Scope: unblock `ExternalSecret/libreplay-secrets` in namespace `libreplay-staging` by creating the Vault KV v2 record that External Secrets reads as `secret/libreplay/staging`.

## RHO Checklist

### Directives

- [x] Do not print or commit secret values. Evidence: this document contains only key names, source expectations, and validation rules.
- [x] Do not manually create `Secret/libreplay-secrets` in Kubernetes. Evidence: source of truth remains Vault through `ExternalSecret/libreplay-secrets`.
- [x] Do not repoint Argo to `staging/overlays/runtime` until strict preflight passes. Evidence: `scripts/check-libreplay-staging-preflight.sh --strict` is blocked while the Vault record is absent.
- [x] Do not reuse adjacent Skirmshop/other OAuth credentials unless their provider console explicitly includes LibrePlay staging redirect URIs.
- [x] Require non-secret provider evidence before any Vault write. Evidence: `scripts/check-libreplay-staging-secret-evidence.sh --strict --vault-write` validates callback URI metadata and SMTP sender metadata without printing secrets.

### Acceptance Criteria

- [ ] Vault KV v2 record exists at `secret/libreplay/staging`. Evidence required: ESO status `Ready=True` for `ExternalSecret/libreplay-secrets`.
- [ ] The materialized Kubernetes Secret contains the 19 required keys below. Evidence required: key-name-only check, never values.
- [ ] Google OAuth app is LibrePlay-specific or explicitly configured for `https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback`. Evidence required: provider console/config screenshot or metadata, no secret value.
- [ ] Facebook OAuth app is LibrePlay-specific or explicitly configured for `https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback`. Evidence required: provider console/config screenshot or metadata, no secret value.
- [ ] SMTP credentials are authorized to send `LibrePlay <noreply@libreplay.e-dani.com>`. Evidence required: SMTP provider/domain verification metadata and a staging email smoke after runtime exists.
- [ ] Controlled staging mailbox exists for GitHub environment secret `PW_STAGING_AUTH_EMAIL`, and plus-addressing/catch-all behavior is confirmed through `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1`. Evidence required: `scripts/check-libreplay-staging-secret-evidence.sh --strict` passes without printing the mailbox value.
- [ ] `OAUTH_TOKEN_ENC_KEY` is exactly 64 hex chars. Evidence required: length/regex check only.
- [ ] `METRICS_BEARER_TOKEN` is a high-entropy random token for VictoriaMetrics scrape auth. Evidence required: existence/length check only.
- [ ] `scripts/check-libreplay-staging-preflight.sh --strict` passes before enabling runtime overlay.

## Required Vault Fields

| Key | Source | Validation | Status |
| --- | --- | --- | --- |
| `DATABASE_URL` | Generated from staging DB user/password and in-cluster service name | PostgreSQL URL for `libreplay-postgres.libreplay-staging.svc.cluster.local:5432` | [ ] |
| `REDIS_URL` | Generated from in-cluster Redis service name | Redis URL for `libreplay-redis.libreplay-staging.svc.cluster.local:6379` | [ ] |
| `AUTH_SECRET` | Generate new random secret | At least 32 chars; prefer 32+ random bytes encoded base64url/hex | [ ] |
| `MINIO_ACCESS_KEY` | Generate new staging-only key | Non-empty; must match MinIO deployment env | [ ] |
| `MINIO_SECRET_KEY` | Generate new staging-only secret | Non-empty; must match MinIO deployment env | [ ] |
| `MEILISEARCH_API_KEY` | Generate new staging-only key | Non-empty; must match Meilisearch env | [ ] |
| `DB_USER` | Generate or choose staging DB role | Non-empty; must match `DATABASE_URL` user | [ ] |
| `DB_PASSWORD` | Generate new staging-only password | Non-empty; must match `DATABASE_URL` password | [ ] |
| `SEED_USER_PASSWORD` | Generate new staging-only password | Non-empty; used only by seed job/demo users | [ ] |
| `GOOGLE_CLIENT_ID` | Google OAuth provider | Must belong to app authorized for LibrePlay staging callback | [blocked] Missing LibrePlay-specific credential evidence |
| `GOOGLE_CLIENT_SECRET` | Google OAuth provider | Must pair with `GOOGLE_CLIENT_ID`; at least 16 chars; not placeholder-like | [blocked] Missing LibrePlay-specific credential evidence |
| `FACEBOOK_CLIENT_ID` | Meta/Facebook OAuth provider | Must belong to app authorized for LibrePlay staging callback | [blocked] Missing LibrePlay-specific credential evidence |
| `FACEBOOK_CLIENT_SECRET` | Meta/Facebook OAuth provider | Must pair with `FACEBOOK_CLIENT_ID`; at least 16 chars; not placeholder-like | [blocked] Missing LibrePlay-specific credential evidence |
| `OAUTH_TOKEN_ENC_KEY` | Generate new random 32 bytes | Exactly 64 hex chars | [ ] |
| `SMTP_HOST` | SMTP provider | Hostname for a verified sender/domain | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_PORT` | SMTP provider | Positive integer; `465` when `SMTP_SECURE=true` | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_USER` | SMTP provider | Non-empty user/API user | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_PASSWORD` | SMTP provider | At least 16 chars; not placeholder-like | [blocked] Missing LibrePlay-specific SMTP evidence |
| `METRICS_BEARER_TOKEN` | Generate new random secret | High-entropy bearer token for `/api/metrics`; never print value | [ ] |

## Current Evidence

Latest independent verification: **2026-06-24** (Claude verifier, read-only). Report:
`.rho/claude-subagents/libreplay/prod-10a-real-auth-smtp-staging-current/verifier-minimal.report.md`.
Verdict: **BLOCKED, fail-closed** (`BLOCKED_BY_EXTERNAL_CREDENTIALS_AND_PROVIDER_EVIDENCE`
independently verified TRUE). No secret values were printed or recorded. Current Argo
revision for both apps: `ce67574` on `deploy/prod` (source `main` HEAD `48a9dd0`).

> Run the evidence script with **bash** (`bash scripts/check-libreplay-staging-secret-evidence.sh --strict`)
> or execute it directly (`./scripts/check-libreplay-staging-secret-evidence.sh --strict`).
> It is Bash-only (`set -o pipefail`, `[[ ... ]]`, `${!var}`); running it under POSIX `sh`/dash
> now exits early with a clear "requires bash" message (exit 2) instead of pipefail noise.

State confirmed on 2026-06-24:

- `scripts/check-libreplay-staging-preflight.sh --strict` reports exactly **two blockers**: `ExternalSecret/libreplay-secrets` is `Ready=False|SecretSyncedError` ("could not get secret data from provider"), and `Secret/libreplay-secrets` is **not materialized** (absent).
- `scripts/check-libreplay-staging-secret-evidence.sh --strict` (run with bash) reports **seven blockers**: provider callbacks, Google redirect URI, Facebook redirect URI, SMTP sender confirmation, SMTP sender identity (mail-from), controlled mailbox, and plus-addressing confirmation. No values were printed.
- Argo `libreplay` is `Synced|Healthy` (path `k8s`); `libreplay-staging` is `Synced|Degraded` (path `staging`) — both at rev `ce67574`, target `deploy/prod`. Degraded is **expected**: contract-only, **0 pods**, no runtime workloads.
- `ExternalSecret/harbor-pull` in `libreplay-staging` is `Ready=True` (SecretSynced) and `secret/harbor-pull` (dockerconfigjson) is present, so the Vault store and ESO controller are working; the failure is specifically the missing Vault record `secret/libreplay/staging`.
- `svc/libreplay-staging-dns-preflight` is an ExternalName placeholder; runtime overlay check passes dry-run and stays fail-closed (mocks disabled, staging Vault path, public HTTPS host, Cloudflare edge allowlist).
- ESO logs confirm the exact provider error: `secret/libreplay/staging` does not exist.
- A Vault metadata read from `vault-0` without an authorized token returned `403 permission denied`; do not bypass Vault access policy.
- Prior 1Password metadata search found no item named LibrePlay or SauvagePlay for OAuth/SMTP. Current re-check is blocked because the Mac 1Password CLI reports `account is not signed in`.
- GitHub repo `pocharlies-org/libreplay` has environment `staging`; the required environment secrets `PW_STAGING_AUTH_EMAIL` and `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED` are not verified/present.
- Local hygiene note (not a deploy blocker): worktree `_worktrees/k8s-gitops-libreplay-staging` is on branch `libreplay-staging-contract`, 2 commits behind `origin/deploy/prod`; the Argo Application CRs themselves are correct.
- 1Password metadata has adjacent candidates, but they are not enough to authorize reuse:
  - Google OAuth candidate `oautnh google auth skirmshop app` has `Client ID`, `Client secret`, and `oauth_keys_json`, but title indicates Skirmshop, not LibrePlay.
  - Facebook candidates are login items with username/password/notes, not confirmed app OAuth credentials.
  - SMTP-adjacent candidates include Resend/Mailrelay/Gmail items, but no verified LibrePlay sender evidence was confirmed.

## Safe Bootstrap Script

Use the bootstrap script when approved LibrePlay staging provider values are
available. It validates shape, generates internal staging-only secrets in memory,
writes the Vault payload through a temporary `0600` JSON file, and never prints
secret values.

Validate the non-secret evidence metadata first. This is the full gate, including
the controlled mailbox for the GitHub environment secret:

```bash
set +x
export LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
export LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
export LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
export LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1
export LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'
export LIBREPLAY_STAGING_AUTH_EMAIL=<controlled-plus-addressable-mailbox>
export LIBREPLAY_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1
scripts/check-libreplay-staging-secret-evidence.sh --strict
```

Dry-run with provider values already exported:

```bash
set +x
scripts/bootstrap-libreplay-staging-secrets.sh --dry-run
```

Write only after Google/Meta callback evidence and SMTP sender/domain evidence
are confirmed:

```bash
set +x
export LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
export LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
export LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
export LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1
export LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'
scripts/bootstrap-libreplay-staging-secrets.sh --write --sync-eso
```

The script intentionally refuses write mode without these acknowledgements:

- `LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1`
- `LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback`
- `LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback`
- `LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1`
- `LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'`

## Safe Push Procedure

Use this only after all blocked provider fields have approved values available.
Keep shell tracing disabled and do not echo values. Prefer the bootstrap script;
do not use `vault kv put key="$VALUE"` command-line arguments for real secret
values because they can be exposed through process inspection.

```bash
set +x
# export GOOGLE_CLIENT_ID=...
# export GOOGLE_CLIENT_SECRET=...
# export FACEBOOK_CLIENT_ID=...
# export FACEBOOK_CLIENT_SECRET=...
# export SMTP_HOST=...
# export SMTP_PORT=...
# export SMTP_USER=...
# export SMTP_PASSWORD=...
export LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
export LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
export LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
export LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1
export LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'

scripts/bootstrap-libreplay-staging-secrets.sh --write --sync-eso
```

After push, validate by status and key names only:

```bash
kubectl -n libreplay-staging get externalsecret libreplay-secrets
kubectl -n libreplay-staging get secret libreplay-secrets \
  -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' | sort
./scripts/check-libreplay-staging-preflight.sh --strict
```

## PSP / Stripe Note

Stripe is not approved as the default LibrePlay PSP at this time. Official Stripe restricted-business documentation lists adult services, pay-per-view adult content, adult live-chat, and pornography/mature sexual content as prohibited or requiring written pre-approval. Do not set a Stripe provider live until a written approval path exists for LibrePlay's actual product scope.
