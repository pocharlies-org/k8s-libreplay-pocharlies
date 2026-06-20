# LibrePlay Staging Secrets Intake

Owner: PMO / DevOps / Security
Date: 2026-06-20

Scope: unblock `ExternalSecret/libreplay-secrets` in namespace `libreplay-staging` by creating the Vault KV v2 record that External Secrets reads as `secret/libreplay/staging`.

## RHO Checklist

### Directives

- [x] Do not print or commit secret values. Evidence: this document contains only key names, source expectations, and validation rules.
- [x] Do not manually create `Secret/libreplay-secrets` in Kubernetes. Evidence: source of truth remains Vault through `ExternalSecret/libreplay-secrets`.
- [x] Do not repoint Argo to `staging/overlays/runtime` until strict preflight passes. Evidence: `scripts/check-libreplay-staging-preflight.sh --strict` is blocked while the Vault record is absent.
- [x] Do not reuse adjacent Skirmshop/other OAuth credentials unless their provider console explicitly includes LibrePlay staging redirect URIs.

### Acceptance Criteria

- [ ] Vault KV v2 record exists at `secret/libreplay/staging`. Evidence required: ESO status `Ready=True` for `ExternalSecret/libreplay-secrets`.
- [ ] The materialized Kubernetes Secret contains the 18 required keys below. Evidence required: key-name-only check, never values.
- [ ] Google OAuth app is LibrePlay-specific or explicitly configured for `https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback`. Evidence required: provider console/config screenshot or metadata, no secret value.
- [ ] Facebook OAuth app is LibrePlay-specific or explicitly configured for `https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback`. Evidence required: provider console/config screenshot or metadata, no secret value.
- [ ] SMTP credentials are authorized to send `LibrePlay <noreply@libreplay.e-dani.com>`. Evidence required: SMTP provider/domain verification metadata and a staging email smoke after runtime exists.
- [ ] `OAUTH_TOKEN_ENC_KEY` is exactly 64 hex chars. Evidence required: length/regex check only.
- [ ] `scripts/check-libreplay-staging-preflight.sh --strict` passes before enabling runtime overlay.

## Required Vault Fields

| Key | Source | Validation | Status |
| --- | --- | --- | --- |
| `DATABASE_URL` | Generated from staging DB user/password and in-cluster service name | PostgreSQL URL for `libreplay-postgres.libreplay-staging.svc.cluster.local:5432` | [ ] |
| `REDIS_URL` | Generated from in-cluster Redis service name | Redis URL for `libreplay-redis.libreplay-staging.svc.cluster.local:6379` | [ ] |
| `AUTH_SECRET` | Generate new random secret | At least 16 chars; prefer 32+ random bytes encoded base64url/hex | [ ] |
| `MINIO_ACCESS_KEY` | Generate new staging-only key | Non-empty; must match MinIO deployment env | [ ] |
| `MINIO_SECRET_KEY` | Generate new staging-only secret | Non-empty; must match MinIO deployment env | [ ] |
| `MEILISEARCH_API_KEY` | Generate new staging-only key | Non-empty; must match Meilisearch env | [ ] |
| `DB_USER` | Generate or choose staging DB role | Non-empty; must match `DATABASE_URL` user | [ ] |
| `DB_PASSWORD` | Generate new staging-only password | Non-empty; must match `DATABASE_URL` password | [ ] |
| `SEED_USER_PASSWORD` | Generate new staging-only password | Non-empty; used only by seed job/demo users | [ ] |
| `GOOGLE_CLIENT_ID` | Google OAuth provider | Must belong to app authorized for LibrePlay staging callback | [blocked] Missing LibrePlay-specific credential evidence |
| `GOOGLE_CLIENT_SECRET` | Google OAuth provider | Must pair with `GOOGLE_CLIENT_ID` | [blocked] Missing LibrePlay-specific credential evidence |
| `FACEBOOK_CLIENT_ID` | Meta/Facebook OAuth provider | Must belong to app authorized for LibrePlay staging callback | [blocked] Missing LibrePlay-specific credential evidence |
| `FACEBOOK_CLIENT_SECRET` | Meta/Facebook OAuth provider | Must pair with `FACEBOOK_CLIENT_ID` | [blocked] Missing LibrePlay-specific credential evidence |
| `OAUTH_TOKEN_ENC_KEY` | Generate new random 32 bytes | Exactly 64 hex chars | [ ] |
| `SMTP_HOST` | SMTP provider | Hostname for a verified sender/domain | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_PORT` | SMTP provider | Positive integer; `465` when `SMTP_SECURE=true` | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_USER` | SMTP provider | Non-empty user/API user | [blocked] Missing LibrePlay-specific SMTP evidence |
| `SMTP_PASSWORD` | SMTP provider | Non-empty secret/API key | [blocked] Missing LibrePlay-specific SMTP evidence |

## Current Evidence

- `scripts/check-libreplay-staging-preflight.sh --strict` currently reports exactly two blockers: `ExternalSecret/libreplay-secrets` is `Ready=False|SecretSyncedError`, and `Secret/libreplay-secrets` is not materialized.
- `ExternalSecret/harbor-pull` in the same namespace is `Ready=True`, so the Vault store and ESO controller are working.
- 1Password metadata search found no item named LibrePlay or SauvagePlay for OAuth/SMTP.
- 1Password metadata has adjacent candidates, but they are not enough to authorize reuse:
  - Google OAuth candidate `oautnh google auth skirmshop app` has `Client ID`, `Client secret`, and `oauth_keys_json`, but title indicates Skirmshop, not LibrePlay.
  - Facebook candidates are login items with username/password/notes, not confirmed app OAuth credentials.
  - SMTP-adjacent candidates include Resend/Mailrelay/Gmail items, but no verified LibrePlay sender evidence was confirmed.

## Safe Push Procedure

Use this only after all blocked provider fields have approved values available. Keep shell tracing disabled and do not echo values.

```bash
set +x
# export DATABASE_URL=...
# export REDIS_URL=...
# export AUTH_SECRET=...
# export MINIO_ACCESS_KEY=...
# export MINIO_SECRET_KEY=...
# export MEILISEARCH_API_KEY=...
# export DB_USER=...
# export DB_PASSWORD=...
# export SEED_USER_PASSWORD=...
# export GOOGLE_CLIENT_ID=...
# export GOOGLE_CLIENT_SECRET=...
# export FACEBOOK_CLIENT_ID=...
# export FACEBOOK_CLIENT_SECRET=...
# export OAUTH_TOKEN_ENC_KEY=...
# export SMTP_HOST=...
# export SMTP_PORT=...
# export SMTP_USER=...
# export SMTP_PASSWORD=...

vault kv put secret/libreplay/staging \
  DATABASE_URL="$DATABASE_URL" \
  REDIS_URL="$REDIS_URL" \
  AUTH_SECRET="$AUTH_SECRET" \
  MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
  MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
  MEILISEARCH_API_KEY="$MEILISEARCH_API_KEY" \
  DB_USER="$DB_USER" \
  DB_PASSWORD="$DB_PASSWORD" \
  SEED_USER_PASSWORD="$SEED_USER_PASSWORD" \
  GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" \
  FACEBOOK_CLIENT_ID="$FACEBOOK_CLIENT_ID" \
  FACEBOOK_CLIENT_SECRET="$FACEBOOK_CLIENT_SECRET" \
  OAUTH_TOKEN_ENC_KEY="$OAUTH_TOKEN_ENC_KEY" \
  SMTP_HOST="$SMTP_HOST" \
  SMTP_PORT="$SMTP_PORT" \
  SMTP_USER="$SMTP_USER" \
  SMTP_PASSWORD="$SMTP_PASSWORD"
```

After push, validate by status and key names only:

```bash
kubectl -n libreplay-staging get externalsecret libreplay-secrets
kubectl -n libreplay-staging get secret libreplay-secrets -o jsonpath='{.data}' | jq 'keys'
./scripts/check-libreplay-staging-preflight.sh --strict
```

## PSP / Stripe Note

Stripe is not approved as the default LibrePlay PSP at this time. Official Stripe restricted-business documentation lists adult services, pay-per-view adult content, adult live-chat, and pornography/mature sexual content as prohibited or requiring written pre-approval. Do not set a Stripe provider live until a written approval path exists for LibrePlay's actual product scope.
