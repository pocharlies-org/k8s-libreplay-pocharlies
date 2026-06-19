# LibrePlay Production Readiness PMO

Status: `NOT-PRODUCTION-READY`
Last updated: 2026-06-19 16:48 Europe/Madrid
Target today: `https://libreplay.lan.e-dani.com`

## Executive Position

LibrePlay is a validated LAN demo, not a production-ready social network.

PMO assessment: do not open this to real users until the P0/P1 gates below are closed with evidence. The LAN validation harness, critical dependency baseline, release automation and worker-backed media queue foundation are now fixed, but the app still lacks production payments, real identity/age verification, real CSAM/media moderation, compression/transcoding, complete mobile validation, production observability, DR rehearsal and legal/compliance sign-off.

## RHO Task Checklist

### Directives

- [x] Treat memory snippets as discovery only. Evidence: full brain reports inspected for 2026-06-18 blocker and 2026-06-19 guardrail completion.
- [x] Verify current repo and cluster state before claiming readiness. Evidence: source/GitOps `git status`, Argo, ConfigMap, pod image/env, Playwright, and `pnpm audit --prod`.
- [x] Separate LAN demo readiness from production readiness. Evidence: runtime has `DEPLOYMENT_MODE=lan-demo`, all mock flags explicitly true, and source production guardrail rejects those flags.
- [x] Record blockers without weakening acceptance criteria. Evidence: this document keeps failing or blocked items open.

### Current Acceptance Evidence

- [x] Source repo exists and is clean. Evidence: `/home/dibanez/k8s/libreplay` on `main`, head `1d86d1d feat(media): stream uploads and add worker image`.
- [x] GitOps repo exists and is clean. Evidence: `/home/dibanez/k8s/k8s-libreplay-pocharlies` on `deploy/prod`, head `e17dc06 feat: deploy libreplay media worker`.
- [x] LAN runtime is healthy. Evidence: Argo `Synced/Healthy`, revision `e17dc062121cd2ca6889625d8bc3210f2675fe0d`; web image `sha-1d86d1d37e2a@sha256:0da74798859d5c8c27261885adfb648ebf6ed88d671ee1de5bef05cfd76255ab`, worker image `worker-sha-1d86d1d37e2a@sha256:4a156bdd8b6851a0d5028a62c886b452f61bc67655a851991086bdae8091fbe5`.
- [x] LAN demo guardrail is active. Evidence: pod env has `DEPLOYMENT_MODE=lan-demo`, `NODE_ENV=production`, `ENABLE_LAN_DEMO_LOGIN=true`, `ENABLE_MOCK_PAYMENTS=true`, `ENABLE_MOCK_LLM=true`.
- [x] Mobile smoke exists and passes. Evidence: full Playwright run includes mobile project tests `71-73` passing.
- [x] Full LAN E2E is green. Evidence: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 PWJSON=/tmp/libreplay-playwright-media-worker-full.json pnpm --filter @libreplay/web exec playwright test --reporter=list` -> `74 passed (1.2m)`.
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
- [blocked] Compression/transcoding is not implemented. Evidence: media package has no `sharp`/video pipeline dependency; `MediaVariant` schema exists but worker only runs mock CSAM/moderation and does not generate variants.
- [ ] Durable media lifecycle exists. Missing: original/variant retention rules, object lifecycle policies, AV scanning, hash dedupe, CDN strategy, backup/restore, orphan cleanup.
- [ ] Video scalability exists. Missing: ffmpeg/MediaConvert pipeline, bitrate ladder, thumbnails, duration/probe extraction, max duration policy, async job UI.

### Trust, Safety, Legal, Compliance

- [x] Moderation/reporting data model exists. Evidence: `Report`, `ModerationCase`, `ModerationAction`, `Appeal`, `AuditLog`, report routes and admin routes.
- [blocked] Real age/face/CSAM/media moderation providers are absent. Evidence: `packages/media/src/providers/index.ts` always resolves mock providers.
- [ ] DSA/GDPR readiness exists. Missing: DPIA, data retention, right-to-erasure/export, notice-and-action endpoint, statement-of-reasons, transparency reporting, locale-specific legal review.
- [ ] Adult platform safety controls are complete. Missing: record keeping, consent documentation enforcement, non-consensual content workflow, minor-safety escalation, repeat offender policy, law-enforcement/NCMEC-equivalent hooks where legally required.

### DevOps / SRE

- [x] LAN GitOps deployment is healthy. Evidence: Argo `Synced/Healthy`; web, Postgres, Redis, Meili and MinIO all 1/1.
- [x] Release automation is complete for current web/tools/seed images. Evidence: GitHub secrets exist by name; source `Release Image` workflow run `27830810054` completed `success`, Harbor login passed, web/tools/seed digests were published, GitOps commit `1329105` deployed the official web digest, and full LAN Playwright on that image returned `73 passed`.
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
  Evidence: `pocharlies-org/libreplay` Release Image run `27830810054` published web/tools/seed digests; `pocharlies-org/k8s-libreplay-pocharlies` CI run `27831093880` passed; Argo is `Synced/Healthy` at GitOps revision `1329105487400b531ebef6c3eb0541288bdb9ba5`; full LAN E2E on the official release image is `73 passed`.
- [x] Deploy media worker separately from web.
  Evidence: source commit `1d86d1d`, CI run `27831861195`, Release Image run `27832114949`, GitOps commit `e17dc06`, GitOps CI run `27832428507`, Argo `Synced/Healthy`, worker logs show media jobs completed, Redis media wait/failed queues are `0`, and full LAN E2E is `74 passed`.

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

- [ ] Add image compression/variants.
  Evidence required: uploaded image generates webp/avif variants and blurred preview; `MediaVariant` rows created; storage size measured.
- [ ] Add video processing pipeline.
  Evidence required: thumbnails, duration/probe, compressed renditions or HLS/DASH, max duration policy, async job progress.
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

`PROD-1-RELEASE-AND-MEDIA-FOUNDATION`

Objective: remove the next production blockers after the validation harness: release automation and scalable media foundations.

Success criteria:

- [x] `Release Image` workflow can publish web/tools/seed without manual Harbor push.
- [x] `/api/media/upload/[id]` streams to S3 instead of buffering whole files in web memory.
- [x] `/api/media/complete` validates object existence before enqueue/complete.
- [x] A `libreplay-worker` Deployment runs BullMQ media jobs; production/staging no longer depend on inline fallback.
- [x] CI, GitOps deployment and full LAN E2E remain green.

Rationale: release automation and worker-backed media queueing are now auditable. Production operation is still blocked by missing image variants/compression, video transcoding, real safety providers and broader HA/observability controls.

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
