# LibrePlay Production Secrets Intake

Owner: PMO / DevOps / Security
Date: 2026-06-20

Scope: prepare a production-only Vault KV v2 record for the static production
contract at `production/libreplay-production-contract.yaml`. This document does
not approve a runtime launch.

## RHO Checklist

### Directives

- [x] Do not print or commit secret values. Evidence: this document contains
  only key names, source expectations and validation rules.
- [x] Keep production separate from LAN and staging. Evidence: production uses
  namespace `libreplay-production` and Vault path `secret/libreplay/production`.
- [x] Do not sync runtime workloads until real provider, PSP, media/CDN,
  safety, backup and compliance gates are closed.
- [x] Do not assume Stripe as PSP. Evidence: production contract keeps
  `PAYMENT_PROVIDER=disabled` until an adult-friendly PSP is selected and
  webhook/signature/ledger controls are implemented.

### Acceptance Criteria

- [ ] Vault KV v2 record exists at `secret/libreplay/production`. Evidence
  required: ESO status `Ready=True` for production `ExternalSecret`.
- [ ] Materialized Kubernetes Secret contains the required key names below.
  Evidence required: key-name-only check, never values.
- [ ] Google OAuth app is approved/configured for
  `https://libreplay.e-dani.com/api/auth/oauth/google/callback`.
- [ ] Facebook OAuth app is approved/configured for
  `https://libreplay.e-dani.com/api/auth/oauth/facebook/callback`.
- [ ] SMTP credentials are authorized to send
  `LibrePlay <noreply@libreplay.e-dani.com>`.
- [ ] Public media URL/CDN host `https://media.libreplay.e-dani.com` is
  provisioned with signed/lifecycle/retention policy before runtime launch.
- [ ] Approved PSP exists. Until then production must keep
  `PAYMENT_PROVIDER=disabled`.
- [ ] Non-auth mocks have real replacements or explicit launch-blocking
  decisions. Production config sets all `ENABLE_MOCK_*` flags to `false`.
- [ ] `scripts/check-libreplay-production-contract.sh` passes before any
  production Argo app is created.

## Required Vault Fields

| Key | Source | Validation | Status |
| --- | --- | --- | --- |
| `DATABASE_URL` | Production DB plan | PostgreSQL URL for production DB/service | [ ] |
| `REDIS_URL` | Production Redis plan | Redis URL for production Redis/service | [ ] |
| `AUTH_SECRET` | Generate production-only random secret | At least 16 chars; prefer 32+ random bytes | [ ] |
| `MINIO_ACCESS_KEY` | Production media storage key | Non-empty; least-privilege preferred | [ ] |
| `MINIO_SECRET_KEY` | Production media storage secret | Non-empty; least-privilege preferred | [ ] |
| `MEILISEARCH_API_KEY` | Production Meilisearch key | Non-empty | [ ] |
| `DB_USER` | Production DB role | Non-empty; matches `DATABASE_URL` | [ ] |
| `DB_PASSWORD` | Production DB password | Non-empty; matches `DATABASE_URL` | [ ] |
| `SEED_USER_PASSWORD` | Production bootstrap/seed password | Non-empty; rotate before/after launch if used | [ ] |
| `GOOGLE_CLIENT_ID` | Google OAuth provider | Must match production callback | [blocked] |
| `GOOGLE_CLIENT_SECRET` | Google OAuth provider | Must pair with `GOOGLE_CLIENT_ID` | [blocked] |
| `FACEBOOK_CLIENT_ID` | Meta/Facebook OAuth provider | Must match production callback | [blocked] |
| `FACEBOOK_CLIENT_SECRET` | Meta/Facebook OAuth provider | Must pair with `FACEBOOK_CLIENT_ID` | [blocked] |
| `OAUTH_TOKEN_ENC_KEY` | Generate 32 random bytes | Exactly 64 hex chars | [ ] |
| `SMTP_HOST` | SMTP provider | Hostname for verified sender/domain | [blocked] |
| `SMTP_PORT` | SMTP provider | Positive integer | [blocked] |
| `SMTP_USER` | SMTP provider | Non-empty user/API user | [blocked] |
| `SMTP_PASSWORD` | SMTP provider | Non-empty secret/API key | [blocked] |
| `METRICS_BEARER_TOKEN` | Generate production-only random token | High-entropy bearer token | [ ] |

## Safe Push Procedure

Use only after provider and internal values are approved. Keep shell tracing
disabled and do not echo values.

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
# export METRICS_BEARER_TOKEN=...

vault kv put secret/libreplay/production \
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
  SMTP_PASSWORD="$SMTP_PASSWORD" \
  METRICS_BEARER_TOKEN="$METRICS_BEARER_TOKEN"
```

Validate by status/key names only:

```bash
scripts/check-libreplay-production-contract.sh
kubectl -n libreplay-production get externalsecret libreplay-secrets
kubectl -n libreplay-production get secret libreplay-secrets \
  -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' | sort
scripts/check-libreplay-production-contract.sh --live
```
