# LibrePlay Staging Auth Runbook

Status: `BLOCKED-BY-REAL-SECRETS`
Last updated: 2026-06-20 07:40 CEST

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

- [x] Argo app `libreplay-staging` exists and targets the contract-only
  staging path. Evidence: `kubectl -n argocd get application libreplay-staging`
  reports `Synced|Degraded|1648469277e96cd7f8eb7e0e5384a8f837becc70|staging`.
- [x] Namespace `libreplay-staging` exists with its own `ExternalSecret`.
  Evidence: `kubectl -n libreplay-staging get externalsecret libreplay-secrets`
  reports `SecretSyncedError`, proving the contract exists but Vault data is
  missing.
- [x] Staging image pull secret contract is declared without printing registry
  credentials. Evidence: `ExternalSecret/harbor-pull` targets
  `infra/harbor/ci-robot` and templates a `kubernetes.io/dockerconfigjson`
  Secret.
- [x] Staging DNS preflight contract is declared without enabling runtime
  workloads. Evidence: `Service/libreplay-staging-dns-preflight` is an
  `ExternalName` annotated for external-dns with hostname
  `libreplay-staging.e-dani.com`, target `57.129.17.172` and
  `cloudflare-proxied=true`; it exists only to let external-dns publish the
  record before the runtime overlay is synced.
- [x] Static staging auth contract exists without enabling live staging.
  Evidence: `staging/libreplay-staging-contract.yaml` contains only Namespace,
  `ExternalSecret` and `ConfigMap`; it does not define workloads or ingress.
- [x] Staging runtime overlay is renderable but not live. Evidence:
  `staging/overlays/runtime` renders the full workload set into `libreplay-staging`
  with real-provider auth posture, required OAuth/SMTP secret refs, public
  `traefik-edge` ingress, external-dns annotations and public TLSStore; it is
  intentionally not the Argo target until real secrets/DNS are present.
- [x] Static runtime guard prevents LAN config drift. Evidence:
  `scripts/check-libreplay-staging-runtime.sh` renders `staging/overlays/runtime`,
  performs client dry-run and rejects LAN host, LAN DB name, mock OAuth,
  console auth email, mock payments, optional OAuth/SMTP secret refs,
  ClientIP-only ingress, missing `traefik-edge`/external-dns/public TLS posture
  and SSO middleware.
- [blocked] Vault/ExternalSecret exposes the required key names without
  printing values. Blocker: live `ExternalSecret/libreplay-secrets` is
  `Ready=False` with `SecretSyncedError` because provider data is absent.
- [x] Static contract can be validated without live secrets. Evidence:
  `scripts/check-libreplay-staging-contract.sh --static` validates key names,
  staging config, non-placeholder HTTPS URLs and non-local `MAIL_FROM`.
- [x] Staging config is real-provider posture at the contract level. Evidence:
  live `ConfigMap/libreplay-config` exists in `libreplay-staging`; static
  contract and runtime checks require `DEPLOYMENT_MODE=staging`,
  `NODE_ENV=production`, `USE_MOCK_OAUTH=false`, `AUTH_EMAIL_PROVIDER=smtp`,
  and HTTPS `APP_BASE_URL`/`AUTH_URL`.
- [ ] Google OAuth start redirects to `accounts.google.com` from staging.
  Evidence required: gated Playwright staging smoke passes.
- [ ] Facebook OAuth start redirects to `facebook.com` from staging.
  Evidence required: gated Playwright staging smoke passes.
- [ ] Registration verification email drains through `auth-email` with no queue failures.
  Evidence required: `/api/health/deps` shows `authEmail` failed `0`.
- [ ] Full LAN E2E still passes after staging work. Evidence required:
  `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 npx playwright test`.
- [ ] Staging preflight is strict-green before runtime sync. Evidence required:
  `scripts/check-libreplay-staging-preflight.sh --strict`.

## DNS And Public Edge Notes

`external-dns` in this cluster watches Services, Ingresses and Traefik proxy
resources, but not `DNSEndpoint` CRDs. The staging contract therefore uses a
DNS-only `ExternalName` Service for preflight. The future runtime overlay then
uses the same hostname/target annotations on the `IngressRoute`.

Before switching Argo from `staging` to `staging/overlays/runtime`, the
`traefik-edge` Helm values must watch namespace `libreplay-staging`; otherwise
the runtime `IngressRoute` can render correctly but remain invisible to the
public edge controller.

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
- `SEED_USER_PASSWORD`
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

Validate the future workload runtime overlay without applying it:

```bash
scripts/check-libreplay-staging-runtime.sh
kubectl apply --dry-run=client -k staging/overlays/runtime
```

Run the live readiness report without printing secrets:

```bash
scripts/check-libreplay-staging-preflight.sh
```

Only when this is expected to pass, enforce the gate:

```bash
scripts/check-libreplay-staging-preflight.sh --strict
```

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

- Argo app `libreplay-staging` exists and targets the contract-only path
  `staging`; it must not be repointed to the runtime overlay yet.
- Namespace `libreplay-staging`, `ConfigMap/libreplay-config` and
  `ExternalSecret/libreplay-secrets` exist.
- `ExternalSecret/libreplay-secrets` is `Ready=False SecretSyncedError` because
  `secret/libreplay/staging` provider data is missing in Vault.
- `ExternalSecret/harbor-pull` is now part of the staging contract and should
  materialize from `infra/harbor/ci-robot`; verify it with the preflight before
  runtime sync.
- DNS-only `Service/libreplay-staging-dns-preflight` must be live and external-dns
  must publish `libreplay-staging.e-dani.com` before TLS/smoke checks can pass.
- `traefik-edge` must include `libreplay-staging` in its watched namespaces
  before the runtime `IngressRoute` can be considered public-edge ready.
- Runtime overlay exists at `staging/overlays/runtime`, but it is intentionally not wired
  into Argo until real secrets, DNS/TLS and pull-secret handling are validated.
- Staging DNS/TLS for `libreplay-staging.e-dani.com` has not been proven live.
- Current `libreplay-secrets` in namespace `libreplay` lacks Google, Facebook,
  OAuth encryption and SMTP provider keys.
- No Google/Meta staging callback smoke has been run.
- No SMTP delivery smoke has been run against a controlled staging mailbox.
