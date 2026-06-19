# LibrePlay PMO Master Checklist

Status: `LAN-DEMO-VALIDATED`
Last updated: 2026-06-19 18:13 Europe/Madrid
Target: `https://libreplay.lan.e-dani.com`

Current production overlay: `NOT-PRODUCTION-READY`.
Evidence: [libreplay-production-readiness-pmo.md](./libreplay-production-readiness-pmo.md) records the 2026-06-19 PMO audit and follow-up validation. LAN validation, release automation, media worker foundation, image variants and video probe/thumbnail groundwork are now green, but production is still blocked by real-provider identity, production video renditions/HLS, payments, DevOps/DR, compliance and observability gaps.

## 2026-06-19 PMO Iteration - Video Groundwork Gate

- [x] Source video groundwork patch committed and pushed. Evidence: source commits `a55c0f6 feat(media): add video probe thumbnails` and `e9a1135 fix(media): bound video processing failures`.
- [x] Source validation passed. Evidence: `pnpm --filter @libreplay/media test` -> `7 passed`; `pnpm --filter @libreplay/jobs test` -> `5 passed`; focused media/jobs typechecks passed; source CI run `27835662179` completed `success`.
- [x] Official release digests were published. Evidence: Release Image run `27836030980` completed `success` for head `e9a11353e9bc51637405a8160b02f000effbf408`; web digest `sha256:45a5e0a804618f780e38e29800aea921bee46f8845154778a46b508db1f4159f`; worker digest `sha256:10b3bfca297d954590dcce9dc8f6d37195335c28815340cd28c9bf6733209da5`; tools digest `sha256:dd14ec3ac07e18a424e324eae8654a363c0fc737d05e543a04e7b72d5529383b`; seed digest `sha256:9744acc106a9ed34147a158533bedf265b902e76648b748882edf5315f995d90`.
- [x] GitOps deploys web and worker by digest. Evidence: GitOps commit `e576d68 feat: deploy libreplay video groundwork`; GitOps CI run `27836441318` completed `success`; `kubectl apply --dry-run=server -f k8s/manifest.yaml` passed.
- [x] Runtime is on the expected revision. Evidence: Argo `Synced/Healthy` at `e576d68442ed5438fc1347d24045ae7a33f9ce50`; `libreplay-web` uses `sha-e9a11353e9bc@sha256:45a5e0a804618f780e38e29800aea921bee46f8845154778a46b508db1f4159f`; `libreplay-worker` uses `worker-sha-e9a11353e9bc@sha256:10b3bfca297d954590dcce9dc8f6d37195335c28815340cd28c9bf6733209da5`; both rollouts completed.
- [x] Worker runtime can process video. Evidence: `kubectl -n libreplay exec deploy/libreplay-worker -- ffmpeg -version` -> `ffmpeg version 5.1.9-0+deb12u1`; `ffprobe -version` -> `ffprobe version 5.1.9-0+deb12u1`.
- [x] Video uploads are probed and thumbnail variant is generated. Evidence: focused LAN Playwright `e2e/33-payments-media.auth.spec.ts` -> `5 passed`, including `video upload is probed and produces a thumbnail variant`.
- [x] Video metadata and thumbnail row exist in DB. Evidence: `MediaAsset` `cmql4l8dw000d31zblcy4a08a` is `VIDEO`, `video/mp4`, `APPROVED`, `durationSeconds=1`, `width=16`, `height=16`; `MediaVariant` has `THUMB_LARGE`, `image/jpeg`, `variants/cmql4l8dw000d31zblcy4a08a/video_thumbnail.jpg`, `sizeBytes=222`, `width=16`, `height=16`.
- [x] Video original and thumbnail exist in S3-compatible storage. Evidence: temporary `minio/mc` pod `mc stat --json` found original `video/cmqk3dkr800006gyso70h639f/1781885449651-lan-demo-video.mp4` with `Content-Type=video/mp4`, size `2210`; thumbnail `variants/cmql4l8dw000d31zblcy4a08a/video_thumbnail.jpg` with `Content-Type=image/jpeg`, size `222`.
- [x] Queues and worker are healthy after video processing. Evidence: worker logs show `media-moderation completed 11` and `12`; Redis `bull:media-moderation` wait/active/delayed/failed all `0`.
- [x] LAN E2E remains green with mobile smoke. Evidence: full LAN Playwright `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-video-full.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `76 passed (1.3m)`, including mobile tests `74-76`.
- [x] Independent DevOps/release verifier pass completed. Evidence: Volta reported PASS for GitOps CI `27836441318`, Argo `Synced/Healthy`, expected e9a1135 digests, ffmpeg/ffprobe runtime and no failed pods/jobs.
- [blocked] Production readiness remains blocked. Evidence: this gate adds probe/thumbnail/max-duration groundwork, but production video renditions/HLS, real CSAM/media moderation providers, HA/backups/observability, real OAuth/email and production payments remain open.

## 2026-06-19 PMO Iteration - Image Variants Gate

- [x] Source image variants patch committed and pushed. Evidence: source commit `282d735 feat(media): generate image variants`.
- [x] Source CI and release automation passed. Evidence: source CI run `27833272292` completed `success`; Release Image run `27833556729` completed `success` for head `282d7355f43eedfae875f7307eb8f30710966a7a`.
- [x] Official image digests were published. Evidence: web `sha256:aac3233831286fc38747f0fd5bd81107174532c7bcfabc4bd4aa903d0d714d66`; tools `sha256:602b39a0b85ff1f3007df22caf410aa294247db59f63ff4d885de95a7f751979`; worker `sha256:fa93aabbca6c3db25851d5cae6d17efd401f28554f39867909adad9b8fc399cb`.
- [x] GitOps deploys web, worker and migration by digest. Evidence: GitOps commit `e92f703 feat: deploy libreplay image variants`; GitOps CI run `27833929688` completed `success`; `kubectl apply --dry-run=server -f k8s/manifest.yaml` passed.
- [x] Runtime is on the expected revision. Evidence: Argo `Synced/Healthy` at `e92f703c606a2d56624132afa9b923c633535118`; `libreplay-web` and `libreplay-worker` rollouts completed with `sha-282d7355f43e` images.
- [x] Database migration applied. Evidence: `Job/libreplay-db-migrate-282d735` completed `1/1`; DB has `MediaVariant.mimeType`, `MediaVariant.sizeBytes`, unique index `MediaVariant_mediaAssetId_kind_mimeType_key` and unique index `MediaVariant_objectKey_key`.
- [x] Worker generates image variants. Evidence: focused media E2E generated asset `cmql2t9ll002htbd0mkoperbu`; DB has five variants: `THUMB_SMALL image/webp`, `THUMB_MEDIUM image/webp`, `THUMB_MEDIUM image/avif`, `THUMB_LARGE image/webp`, `BLURRED_PREVIEW image/webp`, each with `sizeBytes`, width and height.
- [x] Variant objects exist in S3-compatible storage. Evidence: temporary `minio/mc` pod `mc stat` found original `image/png` object plus five variant objects under `variants/cmql2t9ll002htbd0mkoperbu/` with `Content-Type` `image/webp` or `image/avif` and non-zero sizes.
- [x] Variant metadata endpoint is protected. Evidence: anonymous GET `/api/media/cmql2t9ll002htbd0mkoperbu/variants` returned `403 AUTH_REQUIRED`; creator non-owner session returned `403 UNATTACHED`.
- [x] Queues and dependencies are healthy after processing. Evidence: worker logs show jobs `9` and `10` completed; Redis `bull:media-moderation` wait/active/delayed/failed all `0`; `/api/health/deps` reports postgres, redis, minio and meilisearch `ok:true`.
- [x] LAN E2E remains green with mobile smoke. Evidence: focused media Playwright `3 passed`; full LAN Playwright `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-variants-full.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `74 passed (1.8m)`, including mobile tests `72-74`.
- [x] Independent DevOps and QA/media verifier passes completed. Evidence: Franklin reported GitOps manifest PASS for the six expected changes; Beauvoir reported validation-plan PASS only after DB/Redis/worker/S3/perms gates, which were executed and recorded above.
- [blocked] Production readiness remains blocked. Evidence: video pipeline, real CSAM/media moderation providers, HA/backups/observability, real OAuth/email and production payments remain open.

## 2026-06-19 PMO Iteration - Media Worker Foundation Gate

- [x] Source media foundation patch committed and pushed. Evidence: source commit `1d86d1d feat(media): stream uploads and add worker image`.
- [x] `/api/media/upload/[id]` no longer buffers the whole file in web memory. Evidence: [upload route](/home/dibanez/k8s/libreplay/apps/web/src/app/api/media/upload/[id]/route.ts:1) uses `Readable.fromWeb(req.body)` with `ContentLength`; `req.arrayBuffer()` is removed from the media upload route.
- [x] `/api/media/complete` validates S3 object existence/metadata before enqueue. Evidence: [complete route](/home/dibanez/k8s/libreplay/apps/web/src/app/api/media/complete/route.ts:1) calls `headObject`; missing uploads return `409 UPLOAD_NOT_FOUND`, size mismatch returns `400 SIZE_MISMATCH`, storage errors return `503 STORAGE_UNAVAILABLE`.
- [x] `/api/media/complete` no longer falls back to inline processing. Evidence: route imports only `enqueueMediaModeration`; enqueue failure returns `503 MEDIA_QUEUE_UNAVAILABLE` and reverts the asset to `PENDING_UPLOAD`.
- [x] Dedicated worker image is built and published by release automation. Evidence: source CI run `27831861195` completed `success`; Release Image run `27832114949` completed `success` and published worker digest `sha256:4a156bdd8b6851a0d5028a62c886b452f61bc67655a851991086bdae8091fbe5`.
- [x] GitOps deploys web and worker by digest. Evidence: GitOps commit `e17dc06 feat: deploy libreplay media worker`, GitOps CI run `27832428507` completed `success`; server-side dry-run reported `deployment.apps/libreplay-worker created`.
- [x] Runtime worker is healthy and drains media jobs. Evidence: Argo revision `e17dc062121cd2ca6889625d8bc3210f2675fe0d` is `Synced/Healthy`; `libreplay-web` and `libreplay-worker` are `1/1`; worker logs show `[jobs] worker started` and jobs `1-8` completed; Redis `bull:media-moderation:wait=0` and `failed=0`.
- [x] LAN E2E remains green on the media worker release. Evidence: focused media Playwright `3 passed`; full LAN Playwright `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-media-worker-full.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `74 passed (1.2m)`.
- [x] Independent backend, DevOps and release verifier passes completed. Evidence: Pauli reported read-only backend media checklist PASS; Lovelace reported worker deployment checklist PASS with residual production blockers; Nietzsche reported release/media verification PASS.
- [blocked] Production readiness remains blocked. Evidence: video transcoding, real CSAM/media moderation providers, HA/backups/observability, real OAuth/email and production payments remain open.

## 2026-06-19 PMO Iteration - Release Automation Gate

- [x] GitHub release secrets exist by name without exposing values. Evidence: `gh secret list --repo pocharlies-org/libreplay` showed `HARBOR_USER` and `HARBOR_PASSWORD`, updated `2026-06-19T14:12:39Z/14:12:40Z`.
- [x] `Release Image` workflow is active and dispatchable. Evidence: [release.yml](/home/dibanez/k8s/libreplay/.github/workflows/release.yml:1) has `workflow_dispatch`; `gh workflow list` showed it `active`.
- [x] Release workflow publishes web/tools/seed without manual Harbor push. Evidence: `pocharlies-org/libreplay` run `27830810054` completed `success`; `docker/login-action@v3` and `Build and push image` steps passed.
- [x] Official release digests exist. Evidence: `harbor.e-dani.com/homelab/libreplay-web:sha-b3ebad4ac482@sha256:d7eeb53810159c9bc7fc3ed5355eac4d094ba1e7b213932b72ef3601d85df26c`, tools digest `sha256:0b76bf0b6af981dd6a359f99c3788977d8d13ec45eacecac351beaaf1caabe4b`, seed digest `sha256:1593f9054629e2d5de3e151be8ca19b3009cc37645156fc7975726f83f75161c`.
- [x] GitOps deploys the official release web digest. Evidence: GitOps commit `1329105 fix: deploy libreplay release workflow image`, GitOps CI run `27831093880` completed `success`; Argo revision `1329105487400b531ebef6c3eb0541288bdb9ba5` is `Synced/Healthy`, web deployment is `1/1`, observedGeneration `20/20`.
- [x] Full LAN Playwright remains green on the official release image. Evidence: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-release-workflow-b3ebad4.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `73 passed (1.3m)`.
- [x] Independent release verifier pass completed. Evidence: subagent `019ee039-d912-7ee3-8991-4fa651cb98c8` reported PASS for secrets-by-name, workflow run `27830810054`, Harbor login, published digests and read-only preservation.
- [blocked] Production readiness remains blocked. Evidence: no real OAuth secrets/runtime, no real email verification/reset, payments are mock-only, no media compression/transcoding, no HA/backup/observability baseline.

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
- [blocked] Production readiness remains blocked. Evidence: no real OAuth secrets/runtime, no real email verification/reset, payments are mock-only, no media compression/transcoding, no HA/backup/observability baseline.

## Directives

- [x] No exposicion publica; solo LAN/SSO existente. Evidence: `k8s/manifest.yaml` keeps only `IngressRoute/libreplay-lan`.
- [x] No importar ni borrar datos antiguos. Evidence: rollout uses database `libreplay_lan`; no PVC deletion or data import is encoded.
- [x] Sin passwords para usuarios/QA. Evidence: source commit `986ceec2b562...` uses `/api/auth/demo-login`; Playwright no longer references `SEED_AI_USER_PASSWORD` or `E2E_TEST_PASSWORD`.
- [x] Secrets internos siguen en secrets. Evidence: manifest reads `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, MinIO, Meili and `SEED_USER_PASSWORD` from `libreplay-secrets`.
- [x] Mocks visibles como LAN/no-prod. Evidence: ConfigMap enables mock flags; UI has demo/no-prod panel and creator/payment mock copy.
- [x] LAN demo cannot be mistaken for production mode. Evidence: GitOps ConfigMap declares `DEPLOYMENT_MODE=lan-demo`; source env parser rejects `ENABLE_LAN_DEMO_LOGIN` outside `lan-demo` and rejects all critical mocks in `DEPLOYMENT_MODE=production`; web pod template carries config rollout annotation `deployment-mode-lan-demo-20260619-1302` so pods reload ConfigMap env.
- [x] No cerrar con pods caidos, 404s, buttons mudos, skips criticos or missing secrets in LAN validation. Evidence: current full LAN Playwright is `76 passed`, Argo is `Synced/Healthy`, web and worker pods are `1/1`, and reset/rate-limit issues are fixed for `DEPLOYMENT_MODE=lan-demo`.

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
