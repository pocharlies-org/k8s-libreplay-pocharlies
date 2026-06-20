# LibrePlay Staging Auth Runbook

Status: `BLOCKED-BY-REAL-SECRETS`
Last updated: 2026-06-20 05:58 Europe/Madrid

## Objective

Bring LibrePlay from LAN-demo auth validation to a real staging auth posture:
Google OAuth, Facebook Login and SMTP-backed auth emails must be configured in
a separate staging environment before production can be considered.

## RHO Task Checklist

### Directives

- [x] Do not print secret values. Evidence: commands below list key names only.
- [x] Keep staging separate from LAN demo. Evidence: use a dedicated namespace,
  Argo app and Vault path.
- [x] Fail closed. Evidence: `DEPLOYMENT_MODE=staging` requires
  `USE_MOCK_OAUTH=false`, real provider secrets, `OAUTH_TOKEN_ENC_KEY`,
  `AUTH_EMAIL_PROVIDER=smtp`, SMTP host/port and non-local `MAIL_FROM`.
- [blocked] Real provider evidence exists. Blocker: Google, Meta and SMTP
  staging credentials are not present in the current runtime.

### Acceptance Criteria

- [ ] Argo app `libreplay-staging` exists and targets a staging overlay.
  Evidence required: `kubectl -n argocd get application libreplay-staging`.
- [ ] Namespace `libreplay-staging` exists with its own `ExternalSecret`.
  Evidence required: `kubectl -n libreplay-staging get externalsecret`.
- [x] Static staging auth contract exists without enabling live staging.
  Evidence: `staging/libreplay-staging-contract.yaml` contains only Namespace,
  `ExternalSecret` and `ConfigMap`; it does not define workloads or ingress.
- [ ] Vault/ExternalSecret exposes the required key names without printing
  values. Evidence required:
  `scripts/check-libreplay-staging-contract.sh libreplay-staging`.
- [x] Static contract can be validated without live secrets. Evidence:
  `scripts/check-libreplay-staging-contract.sh --static` validates key names,
  staging config, non-placeholder HTTPS URLs and non-local `MAIL_FROM`.
- [ ] Staging config is real-provider posture. Evidence required:
  `DEPLOYMENT_MODE=staging`, `NODE_ENV=production`, `USE_MOCK_OAUTH=false`,
  `AUTH_EMAIL_PROVIDER=smtp`, HTTPS `APP_BASE_URL`/`AUTH_URL`.
- [ ] Google OAuth start redirects to `accounts.google.com` from staging.
  Evidence required: gated Playwright staging smoke passes.
- [ ] Facebook OAuth start redirects to `facebook.com` from staging.
  Evidence required: gated Playwright staging smoke passes.
- [ ] Registration verification email drains through `auth-email` with no queue failures.
  Evidence required: `/api/health/deps` shows `authEmail` failed `0`.
- [ ] Full LAN E2E still passes after staging work. Evidence required:
  `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 npx playwright test`.

## Required Secret Key Names

These keys must exist in the staging secret, but the verification process must
not print their values:

- `DATABASE_URL`
- `REDIS_URL`
- `AUTH_SECRET`
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `MEILISEARCH_API_KEY`
- `DB_USER`
- `DB_PASSWORD`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `FACEBOOK_CLIENT_ID`
- `FACEBOOK_CLIENT_SECRET`
- `OAUTH_TOKEN_ENC_KEY`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`

## Verification Commands

Run these only after the staging namespace/app and ExternalSecret exist:

```bash
scripts/check-libreplay-staging-contract.sh libreplay-staging
```

Validate the static contract without applying it:

```bash
scripts/check-libreplay-staging-contract.sh --static
kubectl apply --dry-run=client -f staging/libreplay-staging-contract.yaml
```

Use server-side dry-run only after `libreplay-staging` exists in the live
cluster; otherwise the server rejects namespaced resources because the dry-run
Namespace is not persisted.

Run the gated real-provider smoke from the source repo:

```bash
cd /home/dibanez/k8s/libreplay/apps/web
PW_STAGING_REAL_AUTH=1 \
PW_STAGING_AUTH_EMAIL=staging-auth-smoke@example.com \
BASE_URL=https://libreplay-staging.e-dani.com \
PWRETRIES=0 \
npx playwright test --project=staging-real-auth --reporter=line
```

The staging smoke is intentionally absent from the default LAN suite. It only
appears when `PW_STAGING_REAL_AUTH=1` is set, so the normal LAN gate remains
strictly skip-free.

`PW_STAGING_AUTH_EMAIL` must be a plus-addressable or catch-all mailbox. The
smoke registers a unique address derived from that value, then waits for the
email-verification job to drain without failures.

## Current Blockers

- No live Argo app named `libreplay-staging`.
- No live namespace named `libreplay-staging`.
- No live `ExternalSecret/libreplay-secrets` for staging.
- Static contract exists at `staging/libreplay-staging-contract.yaml`, but it
  is intentionally not wired into Argo yet.
- Staging DNS/TLS for `libreplay-staging.e-dani.com` has not been proven live.
- Current `libreplay-secrets` in namespace `libreplay` lacks Google, Facebook,
  OAuth encryption and SMTP provider keys.
- No Google/Meta staging callback smoke has been run.
- No SMTP delivery smoke has been run against a controlled staging mailbox.
