# LibrePlay PMO Master Checklist

Status: `LAN-DEMO-VALIDATED`
Last updated: 2026-06-19 16:10 Europe/Madrid
Target: `https://libreplay.lan.e-dani.com`

Current production overlay: `NOT-PRODUCTION-READY`.
Evidence: [libreplay-production-readiness-pmo.md](./libreplay-production-readiness-pmo.md) records the 2026-06-19 PMO audit and follow-up validation. LAN validation is now green, but production is still blocked by real-provider, media, payments, DevOps/DR, compliance and observability gaps.

## 2026-06-19 PMO Iteration - QA/Security Gate

- [x] Source validation patch committed and pushed. Evidence: source commits `97fac1a fix: harden lan demo validation` and `b3ebad4 fix: reset demo users in lan e2e setup`.
- [x] GitOps validation image deployed. Evidence: GitOps commits `779f55e fix: deploy libreplay validation image` and `eb96c48 fix: deploy libreplay demo reset image`.
- [x] Runtime image is pinned by digest. Evidence: `harbor.e-dani.com/homelab/libreplay-web:sha-b3ebad4ac482@sha256:a22212a195bb5e88d1e3f62c9a8b2a60ffb8c2dc2f0068fe36b75d0008996ba1`.
- [x] Argo is current and healthy. Evidence: Argo `Synced/Healthy`, revision `eb96c4880dd495ea265962623239f36723be8122`, operation `Succeeded`.
- [x] Health and dependency smoke pass. Evidence: `/api/health=200`, `/api/health/deps=200`.
- [x] LAN demo reset is protected and functional. Evidence: `/api/auth/demo-reset` without header returned `403`; with `x-libreplay-demo-reset: playwright` returned `200` and `updatedUsers=9`.
- [x] Full LAN Playwright is green and repeatable from persistent data. Evidence: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-b3ebad4.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `73 passed (1.3m)`.
- [x] Production dependency audit is clean. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found`.
- [x] Source CI passed. Evidence: `pocharlies-org/libreplay` CI run `27830389764` completed `success`.
- [x] GitOps CI passed. Evidence: `pocharlies-org/k8s-libreplay-pocharlies` CI run `27830499649` completed `success`.
- [blocked] Production readiness remains blocked. Evidence: no real OAuth secrets/runtime, no real email verification/reset, payments are mock-only, no media worker/transcoding, release workflow secrets remain missing, no HA/backup/observability baseline.

## Directives

- [x] No exposicion publica; solo LAN/SSO existente. Evidence: `k8s/manifest.yaml` keeps only `IngressRoute/libreplay-lan`.
- [x] No importar ni borrar datos antiguos. Evidence: rollout uses database `libreplay_lan`; no PVC deletion or data import is encoded.
- [x] Sin passwords para usuarios/QA. Evidence: source commit `986ceec2b562...` uses `/api/auth/demo-login`; Playwright no longer references `SEED_AI_USER_PASSWORD` or `E2E_TEST_PASSWORD`.
- [x] Secrets internos siguen en secrets. Evidence: manifest reads `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, MinIO, Meili and `SEED_USER_PASSWORD` from `libreplay-secrets`.
- [x] Mocks visibles como LAN/no-prod. Evidence: ConfigMap enables mock flags; UI has demo/no-prod panel and creator/payment mock copy.
- [x] LAN demo cannot be mistaken for production mode. Evidence: GitOps ConfigMap declares `DEPLOYMENT_MODE=lan-demo`; source env parser rejects `ENABLE_LAN_DEMO_LOGIN` outside `lan-demo` and rejects all critical mocks in `DEPLOYMENT_MODE=production`; web pod template carries config rollout annotation `deployment-mode-lan-demo-20260619-1302` so pods reload ConfigMap env.
- [x] No cerrar con pods caidos, 404s, buttons mudos, skips criticos or missing secrets in LAN validation. Evidence: current full LAN Playwright is `73 passed`, Argo is `Synced/Healthy`, pod is `1/1`, and reset/rate-limit issues are fixed for `DEPLOYMENT_MODE=lan-demo`.

## Acceptance Criteria

- [x] Argo `libreplay` `Synced/Healthy`. Evidence: revision `05f3c349a4ed07d4e67e9c31fc2cf01ff7732f22`, sync `Synced`, health `Healthy`, phase `Succeeded`.
- [x] Pods ready: Postgres, Redis, MinIO, Meili, web. Evidence: `kubectl -n libreplay get pods,jobs,deploy,endpointslice -o wide` shows Postgres/Redis/MinIO/Meili/web `1/1 Running`, jobs `Complete`, web endpoint `10.42.0.32:3000`.
- [x] `/api/health` and `/api/health/deps` return 200. Evidence: `curl -sk .../api/health` and `.../api/health/deps` returned `HTTP 200`; deps checks postgres/redis/minio/meilisearch all `ok:true`.
- [x] Demo login works for member, moderator, admin, creator, club owner and newbie without typing passwords. Evidence: API smoke returned `200` for member `/feed`, moderator `/admin`, admin `/admin`, creator `/creator/dashboard`, clubowner `/events/new`, newbie `/onboarding`; newbie repeated twice to prove reset/reusability.
- [x] Feed, discover, friends, messages, profiles, groups, clubs, dates, events, forum, blog, map, creator, admin, verification mock and payments mock work. Evidence: full Playwright LAN suite passed all feature specs, including creator payments mock, verification mock, media upload proxy and role projects.
- [x] Playwright LAN full suite passes with trace/screenshot/video and zero critical skips. Evidence: `/tmp/libreplay-playwright-results.json` stats `expected=73`, `unexpected=0`, `flaky=0`, `skipped=0`; artifacts: `73` trace zips, `72` screenshots, `72` videos, HTML report present. One API-only test has no page screenshot/video.
- [x] Checklist final updated with commands, outputs and resolved blockers. Evidence: this file updated after final Argo, smoke, policy and Playwright verification.

## Source / Build

- [x] LAN demo source committed. Evidence: `/home/dibanez/k8s/libreplay` commits through `2365959 fix: make LAN demo e2e repeatable` pushed to `origin/main`.
- [x] Source canonical repo is in the ARC-backed org. Evidence: `origin` for `/home/dibanez/k8s/libreplay` is `git@github.com:pocharlies-org/libreplay.git`; previous personal repo remains as remote `personal` for traceability.
- [x] Source CI runs on ARC `arc-k8s` and is green. Evidence: `pocharlies-org/libreplay` run `27820394287` completed successfully on 2026-06-19; job `verify` passed `checkout`, `pnpm/action-setup`, `setup-node`, `pnpm install --frozen-lockfile`, Prisma generate, typecheck, unit tests, web build and Docker build smoke in `5m45s`.
- [x] Production safety env guardrails have unit/CI coverage. Evidence: source commit `61c6dff feat(config): add deployment mode guardrails`; tests cover `DEPLOYMENT_MODE=lan-demo`, production mock rejection, demo-login rejection outside LAN demo and strict string boolean parsing; local `pnpm test`, `pnpm typecheck`, `pnpm --filter @libreplay/web build` passed; `pocharlies-org/libreplay` CI run `27821491050` passed `typecheck`, unit tests, web build and Docker build smoke in `4m59s`.
- [x] Guardrail image published for runtime. Evidence: local Docker build/push from source commit `61c6dff`; image `harbor.e-dani.com/homelab/libreplay-web:sha-61c6dffb1b0c@sha256:46a00da87e50fb0dae9f77d4b5e458902e1e422eab82f7a732b91bd4380bfb43`.
- [x] `pnpm install --frozen-lockfile`. Evidence: exited 0; lockfile up to date and already up to date.
- [x] `pnpm typecheck`. Evidence: exited 0 on 2026-06-19.
- [x] `pnpm test`. Evidence: exited 0; config 4 tests, security 7 tests, auth no-tests pass, web 8 tests.
- [x] `pnpm lint`. Evidence: exited 0; one pre-existing Next font warning only.
- [x] `pnpm --filter @libreplay/web build`. Evidence: exited 0 and generated routes including `/api/auth/demo-login`, `/api/health/deps`, `/api/media/upload/[id]`.
- [x] Docker runner/tools/seed smoke builds. Evidence: local `docker build --target runner|tools|seed` exited 0.

## Images / Harbor

- [x] Web image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:sha-61c6dffb1b0c@sha256:46a00da87e50fb0dae9f77d4b5e458902e1e422eab82f7a732b91bd4380bfb43`.
- [x] Migrate tools image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:tools-sha-59e051279464@sha256:d5183716a46f849f8f1df8676767f2c00a92cd5e29e1d2b1caf8bb51cbd029db`.
- [x] Seed image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:seed-sha-15da141534f1@sha256:d1c44a5a95ae5330f8f1ce42b25412f88d702b65bee3dc58ce872e67142bfa77`.
- [x] Image labels match source. Evidence: web image label `org.opencontainers.image.revision=61c6dffb1b0cd177cf54e5eded0ebee4140d7d09`; tools returned `59e0512794648a4ce46c5e90007ebbfabedd4099`; seed returned `15da141534f1d75c4d638940113875b02e2aba00`.

## GitOps

- [x] Work is on Argo target branch. Evidence: repo branch `deploy/prod`, Argo target revision previously verified as `deploy/prod`.
- [x] Web image pinned by digest; no `latest`. Evidence: `k8s/manifest.yaml`.
- [x] Datastores scale to one replica. Evidence: StatefulSet/Deployments for Postgres, Redis, Meili and MinIO use `replicas: 1`.
- [x] DB fresh target is `libreplay_lan`. Evidence: Postgres `POSTGRES_DB=libreplay_lan`; `libreplay-db-init` creates DB if existing PVC lacks it.
- [x] MinIO bucket init is explicit. Evidence: `Job/libreplay-minio-init`.
- [x] Migrate and seed are real Jobs. Evidence: `Job/libreplay-db-migrate-59e0512` and `Job/libreplay-db-seed-15da141`.
- [x] Job memory limits present. Evidence: all Jobs set memory requests/limits.
- [x] Server-side manifest dry-run passes. Evidence: `kubectl apply --dry-run=server -f k8s/manifest.yaml` exited 0; only last-applied annotation warnings on pre-existing resources.
- [x] Live Argo sync complete. Evidence: GitOps commit `05f3c34 fix: update libreplay LAN web image` pushed; Argo revision `05f3c349a4ed07d4e67e9c31fc2cf01ff7732f22`, sync `Synced`, health `Healthy`.

## Runtime Secrets

- [x] `harbor-pull` exists in namespace `libreplay`. Evidence: namespace pulls private Harbor images successfully; web pod pulled `sha-23659593fb24` and jobs pulled tools/seed images.
- [x] Vault/ExternalSecret exposes required app keys. Evidence: key names only from `kubectl -n libreplay get secret libreplay-secrets`: `AUTH_SECRET`, `DATABASE_URL`, `DB_PASSWORD`, `DB_USER`, `MEILISEARCH_API_KEY`, `MEILI_MASTER_KEY`, `MINIO_ACCESS_KEY`, `MINIO_BUCKET`, `MINIO_ROOT_PASSWORD`, `MINIO_ROOT_USER`, `MINIO_SECRET_KEY`, `REDIS_URL`, `SEED_USER_PASSWORD`.
- [x] Generated internal secrets are not printed or committed. Evidence: final verification lists only secret key names; `git status --short` clean in source and GitOps repos.

Required keys: `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`, `MEILISEARCH_API_KEY`, `DB_USER`, `DB_PASSWORD`, `SEED_USER_PASSWORD`.

## Specialist Checks

- [x] Research/PMO pass. Evidence: memory source `rollout-2026-06-18T18-26-33...` used as clue and revalidated with repo/cluster commands.
- [x] DevOps read-only pass. Evidence: subagent reported blockers: missing `harbor-pull`, incomplete secret contract, job policy failures, no endpoints.
- [x] QA/Security read-only pass. Evidence: subagent reported blockers: local source not deployed, demo session risk, missing Playwright demo coverage.
- [x] Backend/frontend implementation pass. Evidence: demo login, health deps, upload proxy, seed and Playwright role projects implemented in commit `986ceec`.
- [x] Runtime verification pass. Evidence: Argo/pods/health/demo roles/policy reports/Playwright LAN all passed on 2026-06-19.

## Final Verification Evidence

- [x] Playwright LAN: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWSCREENSHOT=on PWVIDEO=on PWJSON=/tmp/libreplay-playwright-results.json npx playwright test --trace on` -> `73 passed` in `1.6m`, `skipped=0`, `unexpected=0`, `flaky=0`.
- [x] Artifacts archived locally. Evidence: `apps/web/playwright-report` 88M, `apps/web/test-results` 87M, `/tmp/libreplay-playwright-results.json` 172K.
- [x] Policy reports clear for P0/P1. Evidence: no critical/high failures in namespaced `policyreport` or `clusterpolicyreport`.
- [x] Runtime logs checked. Evidence: web logs show Next ready; only non-blocking AWS SDK future Node >=22 warning.
- [x] Historical warning reconciled. Evidence: events still contain old `libreplay-db-migrate-5dffe73` backoff warning, but current `libreplay-db-migrate-59e0512` is `Complete` and Argo is `Healthy`.
