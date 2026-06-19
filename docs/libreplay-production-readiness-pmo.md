# LibrePlay Production Readiness PMO

Status: `NOT-PRODUCTION-READY`
Last updated: 2026-06-19 18:13 Europe/Madrid
Target today: `https://libreplay.lan.e-dani.com`

## Executive Position

LibrePlay is a validated LAN demo, not a production-ready social network.

PMO assessment: do not open this to real users until the P0/P1 gates below are closed with evidence. The LAN validation harness, critical dependency baseline, release automation, worker-backed media queue, image variant generation and video probe/thumbnail groundwork are now fixed, but the app still lacks production payments, real identity/age verification, real CSAM/media moderation, production video renditions/HLS, complete mobile validation, production observability, DR rehearsal and legal/compliance sign-off.

## RHO Task Checklist

### Directives

- [x] Treat memory snippets as discovery only. Evidence: full brain reports inspected for 2026-06-18 blocker and 2026-06-19 guardrail completion.
- [x] Verify current repo and cluster state before claiming readiness. Evidence: source/GitOps `git status`, Argo, ConfigMap, pod image/env, Playwright, and `pnpm audit --prod`.
- [x] Separate LAN demo readiness from production readiness. Evidence: runtime has `DEPLOYMENT_MODE=lan-demo`, all mock flags explicitly true, and source production guardrail rejects those flags.
- [x] Record blockers without weakening acceptance criteria. Evidence: this document keeps failing or blocked items open.

### Current Acceptance Evidence

- [x] Source repo exists and is clean. Evidence: `/home/dibanez/k8s/libreplay` on `main`, head `e9a1135 fix(media): bound video processing failures`.
- [x] GitOps repo exists and is clean. Evidence: `/home/dibanez/k8s/k8s-libreplay-pocharlies` on `deploy/prod`; video groundwork manifest commit `e576d68` is pushed.
- [x] LAN runtime is healthy. Evidence: Argo `Synced/Healthy` at `e576d68442ed5438fc1347d24045ae7a33f9ce50`; runtime web image `sha-e9a11353e9bc@sha256:45a5e0a804618f780e38e29800aea921bee46f8845154778a46b508db1f4159f`, worker image `worker-sha-e9a11353e9bc@sha256:10b3bfca297d954590dcce9dc8f6d37195335c28815340cd28c9bf6733209da5`.
- [x] LAN demo guardrail is active. Evidence: pod env has `DEPLOYMENT_MODE=lan-demo`, `NODE_ENV=production`, `ENABLE_LAN_DEMO_LOGIN=true`, `ENABLE_MOCK_PAYMENTS=true`, `ENABLE_MOCK_LLM=true`.
- [x] Mobile smoke exists and passes. Evidence: full Playwright run includes mobile project tests `74-76` passing.
- [x] Full LAN E2E is green. Evidence: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-video-full.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `76 passed (1.3m)`.
- [x] Production security dependency baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found` after upgrading Next to `15.5.19`, `next-intl` to `4.13.0` and adding transitives overrides.

## Specialist Assessment

### Product / PO

- [x] Core social surfaces exist. Evidence: 49 page routes and 118 API routes under `apps/web/src/app`; E2E covers landing, auth, feed, discover, friends, profiles, messages, dates, events, clubs, groups, forum, blog, creator, admin, media and onboarding.
- [ ] Production onboarding is complete. Missing: real email verification, password reset email delivery, consent capture/versioning UX, abuse-safe profile review, deletion/export flows.
- [ ] A full production product definition exists. Missing: launch markets, legal age rules per country, allowed content policy, monetization policy, moderation SLA, support workflows, trust/safety escalation.
- [ ] Mobile product coverage is complete. Missing: mobile E2E for feed, discover, profile, messages, upload, verification, settings, reports, creator checkout and admin/moderation.

### Frontend / Mobile

- [x] Mobile smoke for auth shell passes. Evidence: mobile Playwright project, iPhone-like viewport, 3 tests passing.
- [blocked] Mobile coverage is insufficient. Evidence: only `13-verify-mobile.mobile.spec.ts` is mobile-specific; it does not cover authenticated social flows.
- [ ] PWA/mobile app readiness exists. Missing: installability, safe-area handling, touch gestures for swipe, file capture from camera, mobile upload progress, offline/error states, Android/iOS cross-browser validation.
- [ ] Accessibility baseline is complete. Missing: automated a11y checks, keyboard flows, screen-reader labels for custom controls, contrast audit across dark UI.

### Backend / Auth

- [x] Credentials and OAuth architecture exists. Evidence: `packages/auth/src/providers/google.ts`, `facebook.ts`, `oauth.ts`, encrypted token fields in `AuthAccount`.
- [blocked] Real Google/Facebook login is not enabled in LAN/prod. Evidence: ConfigMap has `USE_MOCK_OAUTH=true`; live secret keys do not include `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `FACEBOOK_CLIENT_ID`, `FACEBOOK_CLIENT_SECRET` or `OAUTH_TOKEN_ENC_KEY`.
- [ ] Email auth is production-grade. Missing: outbound SMTP/provider, email verification, password reset token email, account recovery and abuse controls.
- [ ] Auth session hardening is complete. Missing: session rotation policy, device/session management UI, 2FA/passkeys, suspicious login alerting.

### Payments / Monetization

- [blocked] Stripe is not a safe default assumption for this product. Evidence: official Stripe restricted-business docs list adult services, pay-per-view adult features, adult live chat and mature audience sexual content as restricted/prohibited; Stripe may require explicit approval or may not support the business.
- [x] Payment domain scaffolding exists. Evidence: `Purchase`, `CreatorSubscription`, `PaidContentPurchase`, `CreatorMembership`, provider interface and mock payment provider.
- [blocked] Real payments are not integrated. Evidence: no `stripe` package, no `STRIPE_*` envs, routes are `/mock`, provider is `mockPaymentProvider`.
- [ ] Adult-friendly PSP decision exists. Missing: compliance-approved PSP, marketplace/payout/KYC model, webhook idempotency, chargeback/refund/negative-balance handling, tax/VAT handling.

### Media / S3 / Compression

- [x] S3-compatible storage path exists. Evidence: `packages/media/src/s3.ts`, first-party upload endpoint, private MinIO deployment, `MediaAsset`/`MediaVariant` schema.
- [x] Scalable media queue foundation exists. Evidence: `/api/media/complete` validates S3 object metadata, enqueues BullMQ only, has no inline processing fallback, and `Deployment/libreplay-worker` is running `1/1` with Redis wait/failed queues at `0`.
- [x] Image compression/variants are implemented for LAN runtime. Evidence: source commit `282d735`; worker uses `sharp` to generate WebP/AVIF thumbnails and blurred preview; DB has five `MediaVariant` rows for test asset `cmql2t9ll002htbd0mkoperbu`; MinIO `mc stat` confirms original plus five variant objects with non-zero sizes and correct content types.
- [x] Video probe/thumbnail groundwork is implemented for LAN runtime. Evidence: source commits `a55c0f6` and `e9a1135`; Release Image run `27836030980`; GitOps commit `e576d68`; worker runtime has `ffmpeg`/`ffprobe` `5.1.9`; focused media Playwright `5 passed`; DB asset `cmql4l8dw000d31zblcy4a08a` has `durationSeconds=1`, `width=16`, `height=16`, and `THUMB_LARGE image/jpeg` variant; MinIO confirms original `video/mp4` and thumbnail `image/jpeg` objects.
- [blocked] Production video transcoding/renditions are not complete. Evidence: probe, max-duration policy and thumbnail generation exist, but compressed video renditions, HLS/DASH, bitrate ladder, CDN strategy, async progress UI and lifecycle policies are still absent.
- [ ] Durable media lifecycle exists. Missing: original/variant retention rules, object lifecycle policies, AV scanning, hash dedupe, CDN strategy, backup/restore, orphan cleanup.
- [ ] Video scalability exists. Missing: compressed renditions or HLS/DASH, bitrate ladder, CDN strategy, async job progress UI, retention/lifecycle policies and production worker scaling.

### Trust, Safety, Legal, Compliance

- [x] Moderation/reporting data model exists. Evidence: `Report`, `ModerationCase`, `ModerationAction`, `Appeal`, `AuditLog`, report routes and admin routes.
- [blocked] Real age/face/CSAM/media moderation providers are absent. Evidence: `packages/media/src/providers/index.ts` always resolves mock providers.
- [ ] DSA/GDPR readiness exists. Missing: DPIA, data retention, right-to-erasure/export, notice-and-action endpoint, statement-of-reasons, transparency reporting, locale-specific legal review.
- [ ] Adult platform safety controls are complete. Missing: record keeping, consent documentation enforcement, non-consensual content workflow, minor-safety escalation, repeat offender policy, law-enforcement/NCMEC-equivalent hooks where legally required.

### DevOps / SRE

- [x] LAN GitOps deployment is healthy. Evidence: Argo `Synced/Healthy`; web, Postgres, Redis, Meili and MinIO all 1/1.
- [x] Release automation is complete for current web/tools/seed/worker images. Evidence: GitHub secrets exist by name; source `Release Image` workflow run `27832114949` completed `success`, Harbor login passed, web/tools/seed/worker digests were published, GitOps commit `e17dc06` deployed the official web and worker digests, and full LAN Playwright on that image returned `74 passed`.
- [x] Release automation remains complete for image variants. Evidence: source `Release Image` workflow run `27833556729` completed `success`; GitOps commit `e92f703` deploys web/tools/worker digests for source `282d735`; GitOps CI run `27833929688` completed `success`; Argo is `Synced/Healthy`.
- [x] Release automation remains complete for video groundwork. Evidence: source `Release Image` workflow run `27836030980` completed `success`; GitOps commit `e576d68` deploys web/worker digests for source `e9a1135`; GitOps CI run `27836441318` completed `success`; Argo is `Synced/Healthy`.
- [blocked] Production scale/HA is missing. Evidence: GitOps now has web plus worker, but still runs single replicas for web, worker, Postgres, Redis, Meili and MinIO; no HPA, PDB, NetworkPolicy, backup CronJobs or restore rehearsal.
- [ ] Observability is production-grade. Missing: metrics, dashboards, structured logs, error tracking, alerting, SLOs, synthetic checks.
- [ ] Disaster recovery is rehearsed. Missing: backup jobs, restore runbook, RPO/RTO targets, tested restore for Postgres/MinIO/Meili/Redis.

### Security

- [x] Basic security headers exist. Evidence: HTTP response includes `permissions-policy`, `referrer-policy`, `x-content-type-options`, `x-frame-options`.
- [x] Dependency security baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found`.
- [blocked] Rate limiting is not production-grade. Evidence: in-process limiter documented as prototype-only; LAN-only rate allowances were added for validation, but production still needs Redis/distributed enforcement.
- [ ] BOLA/IDOR security review is complete. Missing: systematic tests for media, albums, conversations, reports, admin actions and creator purchases.
- [ ] Secrets/compliance posture is complete. Missing: production OAuth/payment secrets, secret rotation, least privilege S3 credentials, signed URL policy, audit of optional secret behavior.

## P0/P1 Backlog

### P0 - Make Validation Trustworthy

- [x] Fix LAN E2E harness to be idempotent and not rate-limit itself.
  Evidence: full LAN E2E passes from persistent LAN data; `/api/auth/demo-reset` restores demo users/relationships and LAN-only rate allowances prevent QA self-throttling.
- [x] Patch Next.js security baseline.
  Evidence: `pnpm audit --prod` has no known vulnerabilities; `pnpm test`, `pnpm typecheck`, web build, source CI `27830389764`, GitOps CI `27830499649` and Argo rollout pass.
- [x] Fix release image automation.
  Evidence: `pocharlies-org/libreplay` Release Image run `27832114949` published web/tools/seed/worker digests; `pocharlies-org/k8s-libreplay-pocharlies` CI run `27832428507` passed; Argo is `Synced/Healthy`; full LAN E2E on the official release image is `74 passed`.
- [x] Deploy media worker separately from web.
  Evidence: source commit `1d86d1d`, CI run `27831861195`, Release Image run `27832114949`, GitOps commit `e17dc06`, GitOps CI run `27832428507`, Argo `Synced/Healthy`, worker logs show media jobs completed, Redis media wait/failed queues are `0`, and full LAN E2E is `74 passed`.
- [x] Add image compression/variants.
  Evidence: source commit `282d735`, CI run `27833272292`, Release Image run `27833556729`, GitOps commit `e92f703`, GitOps CI run `27833929688`, `Job/libreplay-db-migrate-282d735` complete, Argo `Synced/Healthy`, worker jobs completed, Redis wait/active/delayed/failed queues are `0`, DB contains WebP/AVIF/blurred variants, MinIO confirms variant objects and full LAN E2E is `74 passed`.
- [x] Add video probe/thumbnail/max-duration groundwork.
  Evidence: source commits `a55c0f6` and `e9a1135`, CI run `27835662179`, Release Image run `27836030980`, GitOps commit `e576d68`, GitOps CI run `27836441318`, Argo `Synced/Healthy`, worker runtime has `ffmpeg`/`ffprobe`, focused media E2E is `5 passed`, full LAN E2E is `76 passed`, DB/S3/Redis evidence is recorded in the master checklist.

### P1 - Auth And Identity

- [ ] Configure real Google OAuth production app.
  Evidence required: Google OAuth consent screen/brand verification readiness, `GOOGLE_*` secrets present, `USE_MOCK_OAUTH=false` in non-LAN env, E2E real-provider smoke in staging.
- [ ] Configure real Facebook Login.
  Evidence required: Meta app in Live/App Review state as needed, redirect URI configured, `FACEBOOK_*` secrets present, staging smoke passes.
- [ ] Add email verification and real password reset mail.
  Evidence required: provider configured, tokens stored hashed with expiry, test mail and production mail path covered.

### P1 - Payments

- [ ] Decide PSP for adult/social product before coding Stripe as default.
  Evidence required: written PSP approval or selected adult-friendly PSP contract/technical docs.
- [ ] Replace mock payment provider with provider abstraction selected by env.
  Evidence required: webhook idempotency, signed webhook verification, refunds, subscription lifecycle and purchase access tests.
- [ ] Add creator payout/KYC flow.
  Evidence required: onboarding/KYC status in DB/UI, payout readiness gates, revenue ledger tests.

### P1 - Media

- [x] Add video probe/thumbnail/max-duration groundwork.
  Evidence: source commits `a55c0f6` and `e9a1135`; worker uses `ffprobe`/`ffmpeg` with timeouts; video upload E2E generated `THUMB_LARGE image/jpeg`; DB/S3 evidence recorded for asset `cmql4l8dw000d31zblcy4a08a`.
- [ ] Add production video renditions/HLS pipeline.
  Evidence required: compressed renditions or HLS/DASH, bitrate ladder, async job progress, lifecycle/retention policy, production worker scaling and failure replay plan.
- [ ] Add real CSAM/media moderation provider.
  Evidence required: provider integration tests, positive-match rejection, escalation/logging path, manual review queue.

### P1 - Mobile Product

- [ ] Expand mobile E2E matrix.
  Evidence required: mobile tests cover feed, discover/swipe, profile, messages, upload/camera, verification, settings, reports and creator purchase.
- [ ] Add PWA/mobile readiness.
  Evidence required: manifest, icons, safe-area CSS, touch gestures, mobile performance budget and screenshots.

### P1 - Operations

- [ ] Add HA/scaling baseline.
  Evidence required: HPA/PDB where applicable, resource limits, NetworkPolicies, worker scaling, DB/storage migration plan.
- [ ] Add observability and alerting.
  Evidence required: dashboards, alerts, logs, error tracking, uptime synthetic checks.
- [ ] Add backup/restore rehearsal.
  Evidence required: successful restore report for Postgres, MinIO, Meili and Redis.

## Recommended Next Technical Meta

`PROD-3-AUTH-IDENTITY-REAL-PROVIDERS`

Objective: turn auth from LAN/demo-safe identity into production-grade identity groundwork for Google, Facebook and email without accidentally enabling real external login before secrets, redirect URIs and policy gates are ready.

Success criteria:

- [ ] Runtime has an explicit provider-mode contract: LAN mock, staging real-provider smoke and production real-provider only.
- [ ] Google/Facebook callback, state/nonce, token encryption and account linking paths have negative/positive tests.
- [ ] Optional secrets fail closed in production and remain safe in LAN.
- [ ] Email verification and password reset provider abstraction exists with hashed, expiring tokens and test provider coverage.
- [ ] Source CI, dependency audit, GitOps dry-run, Argo, health checks and full LAN E2E remain green.

Rationale: user login, profiles, payments, moderation and legal controls all depend on reliable identity. This must be validated before real payments or wider mobile/product launch.

## External Policy Notes

- Stripe restricted-business references checked on 2026-06-19:
  - https://stripe.com/en-br/legal/restricted-businesses
  - https://support.stripe.com/questions/prohibited-and-restricted-businesses-list-faqs
- Google OAuth production readiness references checked on 2026-06-19:
  - https://developers.google.com/workspace/guides/configure-oauth-consent
  - https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification
- Meta/Facebook Login references checked on 2026-06-19:
  - https://developers.facebook.com/documentation/facebook-login/guides/permissions
  - https://developers.facebook.com/documentation/facebook-login/guides/permissions/review
