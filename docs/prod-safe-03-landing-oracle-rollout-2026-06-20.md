# LibrePlay PROD-SAFE-03 Landing Oracle Rollout - 2026-06-20

Owner: PMO / Backend / DevOps / Security
Status: `DEPLOYED-LAN-VALIDATED`

## Objective

Deploy source commit `2eb2e3c` so the public `/api/landing/oracle` endpoint
fails closed outside explicit test, development or LAN demo modes, while
preserving the LAN demo experience.

## Directives

- [x] Keep LAN demo behavior explicit. Evidence: runtime ConfigMap still has
  `DEPLOYMENT_MODE=lan-demo` and `ENABLE_MOCK_LLM=true`.
- [x] Keep staging and production mock posture fail-closed. Evidence: staging
  contract and runtime overlay render all safety/LLM mocks as `false`.
- [x] Use immutable image references. Evidence: production web and worker are
  pinned by SHA tag plus digest.
- [x] Preserve unrelated local work. Evidence: infra repo had an unrelated
  local `platform/keycloak-next/RUNBOOK.md` diff and it was not committed.

## Acceptance Criteria

- [x] Source CI passed. Evidence: `pocharlies-org/libreplay` CI run
  `27881976255` completed `success`.
- [x] Release image passed after restoring Harbor LAN ingress. Evidence:
  Release Image run `27882360348` completed `success`.
- [x] Harbor/Traefik blocker recovered. Evidence: `traefik-lan` Helm release
  revision `7` runs on `ubuntu`; `https://harbor.lan.e-dani.com/v2/` returns
  registry `401`; infra commit `72f8f36`.
- [x] Staging safety mock drift is corrected. Evidence: GitOps commit
  `f0d383a`; live `libreplay-staging/libreplay-config` returns
  `false|false|false|false|false` for age, face, CSAM, media moderation and
  LLM mocks.
- [x] Production LAN runtime uses the new web/worker images. Evidence: GitOps
  commit `d8112e4`; Argo `libreplay` is `Synced|Healthy|d8112e4...|k8s`.
- [x] Runtime dependency health is good. Evidence: `/api/health/deps` returned
  `ok=true` with Postgres, Redis, queues, MinIO and Meilisearch healthy.
- [x] Runtime Oracle LAN behavior is preserved. Evidence: POST
  `/api/landing/oracle` returned HTTP `200` with `mock=true` and
  `mode="LAN demo / no-prod"`.
- [x] Full LAN regression passed. Evidence:
  `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 pnpm --filter @libreplay/web test:e2e`
  returned `95 passed (2.0m)`.
- [x] Post-E2E logs are clean. Evidence: web/worker log sweeps over the last
  15 minutes found no matches for error, exception, panic, `ReadableStream`,
  `P1001`, Prisma or Oracle timeout patterns.

## Image Digests

- Web: `harbor.e-dani.com/homelab/libreplay-web:sha-2eb2e3cdc959@sha256:9791ad5509dac3467fbab367cb76a7c4174f87d0e079a7a4eb1152fda6ca011b`
- Worker: `harbor.e-dani.com/homelab/libreplay-web:worker-sha-2eb2e3cdc959@sha256:79b40d6ba6110ee80c60cfce678d8f6952445538ab368401cb8a823d768c6edf`
- Tools: `sha256:6b8a30491641747b2f5edc6c866f3d4ee0d27794f8654b6a97d059298bb35af8`
- Seed: `sha256:8f5f4c0163018503fec322cb7a7b3017ff117867459ebc0fff5181f65f49edc4`

## Residual Blockers

- [blocked] Staging runtime is still contract-only. Blocker:
  `ExternalSecret/libreplay-secrets` is `Ready=False SecretSyncedError` because
  `secret/libreplay/staging` is missing provider data.
- [blocked] Staging preflight DNS check is inconsistent on the local resolver.
  Evidence: `nslookup libreplay-staging.e-dani.com 1.1.1.1` resolves Cloudflare
  A/AAAA records, while the strict preflight reported local DNS unresolved.
- [blocked] LibrePlay is still not production-ready. Blockers remain real
  OAuth/SMTP provider runtime, approved adult-friendly PSP, real identity/age
  verification, CSAM/media moderation providers, CDN/media lifecycle, SLOs,
  synthetics, DR rehearsal and compliance sign-off.

## Specialist Checks

- [x] DevOps auditor pass. Evidence: subagent Anscombe identified the Harbor
  blocker as `traefik-lan` pinned to `nvidia-dgx` under `DiskPressure` and
  recommended moving it to a non-dedicated LAN node.
- [x] PMO integration pass. Evidence: infra Helm values were changed, Helm
  release upgraded, GitOps committed, release rerun, production deployed and
  runtime/E2E validated.
- [x] Verifier pass. Evidence: Argo, pod images, health endpoint, Oracle
  endpoint, Playwright and log sweeps were checked after rollout.
