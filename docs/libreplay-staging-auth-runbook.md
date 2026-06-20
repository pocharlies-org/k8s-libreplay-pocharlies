# LibrePlay Staging Auth Runbook

Status: `BLOCKED-BY-REAL-SECRETS`
Last updated: 2026-06-21 01:35 CEST

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
  `AUTH_EMAIL_PROVIDER=smtp`, SMTP host/port, non-local `MAIL_FROM`,
  Redis-backed fail-closed rate limiting, `TRUST_PROXY_CLIENT_IP=true` and
  `TRUSTED_CLIENT_IP_HEADER=cf-connecting-ip`.
- [blocked] Real provider evidence exists. Blocker: Google, Meta and SMTP
  staging credentials are not present in the current runtime.
- [x] Secret intake exists. Evidence:
  [libreplay-staging-secrets-intake.md](./libreplay-staging-secrets-intake.md)
  maps the required Vault fields, validation rules and no-echo push procedure.
- [x] Non-secret evidence preflight exists. Evidence:
  `scripts/check-libreplay-staging-secret-evidence.sh --strict` validates exact
  Google/Meta callback URI metadata, SMTP sender metadata and staging mailbox
  shape without printing secret values.

### Acceptance Criteria

- [x] Argo app `libreplay-staging` exists and targets the contract-only
  staging path. Evidence: `kubectl -n argocd get application libreplay-staging`
  reports `Synced|Degraded` on path `staging`; it may advance through docs-only
  GitOps commits while remaining contract-only and blocked by missing Vault data.
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
  `cloudflare-proxied=true`; external-dns created the Cloudflare-proxied record
  and preflight reports DNS resolution plus TLS handshake OK.
- [x] Public edge can see future runtime routes. Evidence: infra commit
  `56da136` adds `libreplay-staging` to the `traefik-edge` CRD/Ingress watched
  namespace lists; Argo `traefik-edge` is `Synced|Healthy` and the DaemonSet
  rolled out with provider args containing `libreplay-staging`.
- [x] Static staging auth contract exists without enabling live staging.
  Evidence: `staging/libreplay-staging-contract.yaml` contains only Namespace,
  `ExternalSecret` and `ConfigMap`; it does not define workloads or ingress.
- [x] Staging runtime overlay is renderable but not live. Evidence:
  `staging/overlays/runtime` renders the full workload set into `libreplay-staging`
  with real-provider auth posture, required OAuth/SMTP secret refs, public
  `traefik-edge` ingress, Cloudflare source allowlist middleware, external-dns
  annotations and public TLSStore; it is intentionally not the Argo target until
  real secrets/DNS are present.
- [x] Static runtime guard prevents LAN config drift. Evidence:
  `scripts/check-libreplay-staging-runtime.sh` renders `staging/overlays/runtime`,
  performs client dry-run and rejects LAN host, LAN DB name, mock OAuth,
  console auth email, mock payments, optional OAuth/SMTP secret refs,
  ClientIP-only ingress, missing `traefik-edge`/external-dns/public TLS posture,
  SSO middleware, missing Cloudflare source allowlist, `TRUST_PROXY_CLIENT_IP=false`
  and `TRUSTED_CLIENT_IP_HEADER=x-forwarded-for`.
- [blocked] Vault/ExternalSecret exposes the required key names without
  printing values. Blocker: live `ExternalSecret/libreplay-secrets` is
  `Ready=False` with `SecretSyncedError` because provider data is absent.
- [x] A no-echo bootstrap exists for the future Vault write. Evidence:
  `scripts/bootstrap-libreplay-staging-secrets.sh` generates internal secrets,
  requires provider env vars, refuses write mode without Google/Meta/SMTP
  evidence acknowledgements, and writes via a temporary file instead of process
  arguments.
- [x] Static contract can be validated without live secrets. Evidence:
  `scripts/check-libreplay-staging-contract.sh --static` validates key names,
  staging config, non-placeholder HTTPS URLs and non-local `MAIL_FROM`.
- [x] Staging config is real-provider posture at the contract level. Evidence:
  live `ConfigMap/libreplay-config` exists in `libreplay-staging`; static
  contract and runtime checks require `DEPLOYMENT_MODE=staging`,
  `NODE_ENV=production`, `USE_MOCK_OAUTH=false`, `AUTH_EMAIL_PROVIDER=smtp`,
  `TRUST_PROXY_CLIENT_IP=true`, `TRUSTED_CLIENT_IP_HEADER=cf-connecting-ip`
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

The future runtime `IngressRoute` must stay behind Cloudflare. The runtime
overlay attaches `Middleware/libreplay-staging-cloudflare-only`, sourced from the
current Cloudflare IPv4/IPv6 ranges, and the app trusts only
`cf-connecting-ip` for public client attribution. Do not replace this with raw
`x-forwarded-for` unless the edge trust boundary is redesigned and re-audited.

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
- `METRICS_BEARER_TOKEN`

The field-level source and validation checklist lives in
[libreplay-staging-secrets-intake.md](./libreplay-staging-secrets-intake.md).

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

Prepare the Vault record only after approved Google, Meta and SMTP values are
exported in the shell:

```bash
set +x
export LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
export LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
export LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
export LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1
export LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'
scripts/check-libreplay-staging-secret-evidence.sh --strict --vault-write
scripts/bootstrap-libreplay-staging-secrets.sh --dry-run
scripts/bootstrap-libreplay-staging-secrets.sh --write --sync-eso
scripts/check-libreplay-staging-preflight.sh --strict
```

Run the gated real-provider smoke from the source repo:

```bash
cd /home/dibanez/k8s/libreplay/apps/web
PW_STAGING_REAL_AUTH=1 \
PW_STAGING_AUTH_EMAIL=staging-auth-smoke@libreplay.e-dani.com \
PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1 \
BASE_URL=https://libreplay-staging.e-dani.com \
PWRETRIES=0 \
npx playwright test --project=staging-real-auth --reporter=line
```

The staging smoke is intentionally absent from the default LAN suite. It only
appears when `PW_STAGING_REAL_AUTH=1` is set, so the normal LAN gate remains
strictly skip-free.

`PW_STAGING_AUTH_EMAIL` must be a plus-addressable or catch-all mailbox, and
`PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1` must be set only after that behavior is
verified. The
smoke registers a unique address derived from that value, then waits for the
email-verification job to drain without failures.

## Current Blockers

- Argo app `libreplay-staging` exists and targets the contract-only path
  `staging`; it must not be repointed to the runtime overlay yet.
- Namespace `libreplay-staging`, `ConfigMap/libreplay-config` and
  `ExternalSecret/libreplay-secrets` exist.
- `ExternalSecret/libreplay-secrets` is `Ready=False SecretSyncedError` because
  `secret/libreplay/staging` provider data is missing in Vault; ESO logs report
  `Secret does not exist`.
- `ExternalSecret/harbor-pull` is now part of the staging contract and should
  materialize from `infra/harbor/ci-robot`; current preflight verifies it as OK,
  but it must be checked again immediately before runtime sync.
- DNS-only `Service/libreplay-staging-dns-preflight` is live and external-dns
  has published `libreplay-staging.e-dani.com`; current preflight reports DNS
  and TLS OK.
- `traefik-edge` includes `libreplay-staging` in its watched namespaces.
- Runtime overlay exists at `staging/overlays/runtime`, but it is intentionally not wired
  into Argo until real secrets, DNS/TLS and pull-secret handling are validated.
- Staging DNS/TLS for `libreplay-staging.e-dani.com` is proven live at the
  contract/preflight level, but runtime workloads are still intentionally absent.
- Current `libreplay-secrets` in namespace `libreplay` lacks Google, Facebook,
  OAuth encryption and SMTP provider keys.
- Current 1Password re-check is blocked because the Mac `op` account is not
  signed in; prior metadata did not prove LibrePlay-specific OAuth/SMTP items.
- GitHub environment `staging` now exists for repo `pocharlies-org/libreplay`;
  the required environment secrets `PW_STAGING_AUTH_EMAIL` and
  `PW_STAGING_AUTH_EMAIL_PLUS_CONFIRMED` are still absent.
- Source preflight `scripts/check-libreplay-staging-github-env.sh --strict`
  verifies the workflow/environment and fails closed on the missing
  mailbox secrets without printing secret values.
- No Google/Meta staging callback smoke has been run.
- No SMTP delivery smoke has been run against a controlled staging mailbox.
