# LibrePlay Production Readiness PMO

Status: `NOT-PRODUCTION-READY`
Last updated: 2026-06-19 21:01 Europe/Madrid
Target today: `https://libreplay.lan.e-dani.com`

## Executive Position

LibrePlay is a validated LAN demo, not a production-ready social network.

PMO assessment: do not open this to real users until the P0/P1 gates below are closed with evidence. The LAN validation harness, critical dependency baseline, release automation, worker-backed media queue, image variant generation, video probe/thumbnail groundwork, auth email recovery groundwork, OAuth/CSRF hardening, auth email queueing, redacted console auth-email logs and staging/prod SMTP/OAuth guardrails are now fixed, but the app still lacks real OAuth provider runtime/secrets, production payments, real identity/age verification providers, real CSAM/media moderation, real SMTP provider delivery in staging/prod, production video renditions/HLS, complete mobile validation, production observability, DR rehearsal and legal/compliance sign-off.

## RHO Task Checklist

### Directives

- [x] Treat memory snippets as discovery only. Evidence: full brain reports inspected for 2026-06-18 blocker and 2026-06-19 guardrail completion.
- [x] Verify current repo and cluster state before claiming readiness. Evidence: source/GitOps `git status`, Argo, ConfigMap, pod image/env, Playwright, and `pnpm audit --prod`.
- [x] Separate LAN demo readiness from production readiness. Evidence: runtime has `DEPLOYMENT_MODE=lan-demo`, all mock flags explicitly true, and source production guardrail rejects those flags.
- [x] Record blockers without weakening acceptance criteria. Evidence: this document keeps failing or blocked items open.

### Current Acceptance Evidence

- [x] Source repo exists and is clean. Evidence: `/home/dibanez/k8s/libreplay` on `main`, head `53a8b48 fix(auth): redact console email action urls`.
- [x] GitOps repo exists and is clean. Evidence: `/home/dibanez/k8s/k8s-libreplay-pocharlies` on `deploy/prod`; auth-email queue/redaction manifest commit `6ca7ede` is pushed.
- [x] LAN runtime is healthy. Evidence: Argo `Synced/Healthy` at `6ca7ede05399458c3ba42da9439e638ee0ba52aa`; runtime web image `sha-53a8b4845725@sha256:05ad264d771d1375949583ce4af2383133fe07ad4eb246706c343347d2fc6abe`, worker image `worker-sha-53a8b4845725@sha256:f28dea3a5d6c5c367f4aa01ea3e7809e1d65376811b6e1b419708223330045c7`.
- [x] LAN demo guardrail is active. Evidence: pod env has `DEPLOYMENT_MODE=lan-demo`, `NODE_ENV=production`, `ENABLE_LAN_DEMO_LOGIN=true`, `ENABLE_MOCK_PAYMENTS=true`, `ENABLE_MOCK_LLM=true`.
- [x] Mobile smoke exists and passes. Evidence: full Playwright run includes mobile project tests `77-79` passing.
- [x] Full LAN E2E is green. Evidence: `BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 npx playwright test --reporter=line` from `apps/web` -> `79 passed (1.3m)`.
- [x] Production security dependency baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found` after upgrading Next to `15.5.19`, `next-intl` to `4.13.0` and adding transitives overrides.
- [x] Auth email queue is deployed and drains. Evidence: `/api/health/deps` reports `authEmail` waiting/active/delayed/failed all `0`; worker logs show `[auth-email:password_reset] queued console delivery to=demo-member@libreplay.local` and `auth-email completed 2 password_reset` with no URL or token.

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
- [x] Email verification/password reset groundwork exists. Evidence: source commit `1bbe568`; DB has `EmailVerificationToken` and `PasswordResetToken`; forgot/reset/verify/register routes are wired; forgot-password remains non-enumerating; auth package tests cover token hashing/expiry and email provider posture; focused auth E2E is `6 passed`.
- [x] OAuth mock/token guardrails improved. Evidence: mock OAuth providers are limited to test/development/LAN demo; staging/production missing credentials return provider disabled; OAuth token encryption fails closed in staging/production without `OAUTH_TOKEN_ENC_KEY`; pending-social cookie does not store provider tokens.
- [x] OAuth protocol and account-linking hardening exists before real-provider staging. Evidence: source commit `c37cdca`; Google uses PKCE S256, nonce and `id_token` issuer/audience/nonce validation; Facebook sends documented plain PKCE and does not auto-verify Graph email; OAuth flow metadata is sealed with AES-GCM, scoped by provider+state and TTL; linking is bound to initiating session/user and handles provider/email conflicts plus P2002 races; auth tests are `20 passed`.
- [x] Sensitive auth/account mutation routes enforce browser request origin checks. Evidence: central `enforceAuthOrigin` uses Origin, Referer and Fetch Metadata; focused LAN auth E2E is `7 passed` including cross-site rejection for login/forgot/reset/verify/logout/unlink-social; web/security tests cover production fail-closed and LAN compatibility.
- [blocked] Real Google/Facebook login is not enabled in LAN/prod. Evidence: ConfigMap still has `USE_MOCK_OAUTH=true`; live secret keys do not include `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `FACEBOOK_CLIENT_ID`, `FACEBOOK_CLIENT_SECRET` or `OAUTH_TOKEN_ENC_KEY`.
- [x] Auth email queue/retry groundwork exists. Evidence: source commit `9670441 feat(auth): queue transactional emails`; `register` and `forgot-password` enqueue `auth-email` jobs, worker processes auth email separately from media, `/api/health/deps` exposes queue counts, and completed jobs are removed immediately.
- [x] Console auth-email logging is redacted. Evidence: source commit `53a8b48 fix(auth): redact console email action urls`; final worker logs contain recipient and job metadata only, and `rg 'token=|url=|reset-password|verify-email|password-reset|actionUrl'` against recent worker logs found no matches.
- [blocked] Email auth is not production-grade yet. Evidence: token flows and queue/retry groundwork exist, but real SMTP secrets/runtime, real provider delivery, staging smoke, delivery observability, support recovery workflow and abuse controls are still absent.
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
- [x] Release automation remains complete for auth email recovery. Evidence: source CI run `27837492921` completed `success`; Release Image run `27837784400` completed `success`; GitOps commit `da4868b` deploys web/worker/tools digests for source `1bbe568`; GitOps CI run `27838078792` completed `success`; migration job `libreplay-db-migrate-1bbe568` completed; Argo is `Synced/Healthy`.
- [x] Release automation remains complete for OAuth/CSRF hardening. Evidence: source CI run `27839801643` completed `success`; Release Image run `27840087320` completed `success`; GitOps commit `a3a6567` deploys web/worker/tools digests for source `c37cdca`; GitOps CI run `27840418461` completed `success`; migration job `libreplay-db-migrate-c37cdca` completed; Argo is `Synced/Healthy`.
- [x] Release automation remains complete for auth email queue/redaction. Evidence: source CI run `27842739635` completed `success`; Release Image run `27843010658` completed `success`; GitOps commit `6ca7ede` deploys web/worker digests for source `53a8b48`; GitOps CI run `27843274783` completed `success`; Argo is `Synced/Healthy`.
- [blocked] Production scale/HA is missing. Evidence: GitOps now has web plus worker, but still runs single replicas for web, worker, Postgres, Redis, Meili and MinIO; no HPA, PDB, NetworkPolicy, backup CronJobs or restore rehearsal.
- [ ] Observability is production-grade. Missing: metrics, dashboards, structured logs, error tracking, alerting, SLOs, synthetic checks.
- [ ] Disaster recovery is rehearsed. Missing: backup jobs, restore runbook, RPO/RTO targets, tested restore for Postgres/MinIO/Meili/Redis.

### Security

- [x] Basic security headers exist. Evidence: HTTP response includes `permissions-policy`, `referrer-policy`, `x-content-type-options`, `x-frame-options`.
- [x] Dependency security baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found`.
- [x] Auth/OAuth CSRF and Origin hardening exists. Evidence: source commit `c37cdca`; sensitive auth/account POST routes call central Origin/Fetch Metadata checks before mutation/rate-limit; production/staging fail closed without trusted Origin/Referer; LAN/dev remains compatible with API clients that omit Origin; focused and full LAN E2E pass.
- [blocked] Rate limiting is not production-grade. Evidence: in-process limiter documented as prototype-only; LAN-only rate allowances were added for validation, but production still needs Redis/distributed enforcement.
- [blocked] Site-wide CSRF/token posture is still incomplete. Evidence: auth/account POST routes now enforce Origin/Fetch Metadata, but a double-submit CSRF token and systematic coverage for every non-auth mutating route are still pending.
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
- [x] Add auth email recovery groundwork.
  Evidence: source commit `1bbe568`, CI run `27837492921`, Release Image run `27837784400`, GitOps commit `da4868b`, GitOps CI run `27838078792`, migration job `libreplay-db-migrate-1bbe568` complete, Argo `Synced/Healthy`, focused auth E2E is `6 passed`, full LAN E2E is `78 passed`, DB token tables and audit enum evidence is recorded in the master checklist.
- [x] Harden OAuth protocol and auth/account Origin checks.
  Evidence: source commit `c37cdca`, CI run `27839801643`, Release Image run `27840087320`, GitOps commit `a3a6567`, GitOps CI run `27840418461`, migration job `libreplay-db-migrate-c37cdca` complete, Argo `Synced/Healthy`, focused auth E2E is `7 passed`, OAuth start smoke is `1 passed`, full LAN E2E is `79 passed`, and verifier PASS evidence is recorded in the master checklist.
- [x] Queue transactional auth emails and remove token-bearing console logs.
  Evidence: source commits `9670441` and `53a8b48`, source CI runs `27841894429` and `27842739635`, Release Image runs `27842191060` and `27843010658`, GitOps commits `3c04bb9` and `6ca7ede`, GitOps CI runs `27842488604` and `27843274783`, Argo `Synced/Healthy`, focused auth E2E `7 passed`, full LAN E2E `79 passed`, `/api/health/deps` authEmail queue counts all `0`, and recent worker logs contain no action URL or token.

### P1 - Auth And Identity

- [ ] Configure real Google OAuth production app.
  Evidence required: Google OAuth consent screen/brand verification readiness, `GOOGLE_*` secrets present, `USE_MOCK_OAUTH=false` in non-LAN env, E2E real-provider smoke in staging.
- [ ] Configure real Facebook Login.
  Evidence required: Meta app in Live/App Review state as needed, redirect URI configured, `FACEBOOK_*` secrets present, staging smoke passes.
- [x] Add email verification and password reset token groundwork.
  Evidence: tokens stored hash-only with expiry/single-use semantics; forgot-password remains non-enumerating; reset/verify routes and pages exist; auth tests and LAN E2E pass.
- [x] Add auth email queue/retry groundwork.
  Evidence: `auth-email` BullMQ queue, separate worker handler, route enqueue tests, health queue snapshots, and runtime queue drain verified.
- [ ] Add production email delivery hardening.
  Evidence required: real SMTP or transactional provider secrets, staging delivery smoke, delivery observability, support workflow, abuse controls and dead-letter/replay runbook.
- [x] Harden OAuth protocol before real-provider staging.
  Evidence: Google PKCE S256 plus nonce/id-token validation; Facebook documented PKCE plain challenge plus no auto-verified email trust; sealed provider+state flow cookies; link session/user binding; account-linking provider/email/P2002 conflict tests; focused and full LAN E2E pass.
- [ ] Enable real-provider staging for Google/Facebook.
  Evidence required: Google and Meta app configuration, redirect URI validation, secrets in staging, `USE_MOCK_OAUTH=false`, real-provider smoke tests, and support runbook for provider/app-review failure modes.

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

`PROD-3D-REAL-PROVIDER-SECRETS-STAGING`

Objective: move from LAN auth-email/OAuth groundwork to a real staging auth posture without exposing production traffic.

Success criteria:

- [ ] Google OAuth app/consent and redirect URIs are configured for staging; secrets exist only in secret manager/GitOps secret path.
- [ ] Meta/Facebook Login app is configured for staging; required permissions/app-review posture is documented; secrets exist only in secret manager/GitOps secret path.
- [ ] `USE_MOCK_OAUTH=false` staging deployment starts cleanly with real provider secrets and fails closed if any required secret is missing.
- [ ] Production-grade SMTP/transactional email provider is configured in staging with queue/retry/dead-letter and observability.
- [ ] Staging smoke covers Google login, Facebook login, email verification delivery, password reset delivery, negative provider failures and session/account-linking regressions.
- [ ] Source CI, dependency audit, GitOps dry-run, Argo, health checks and full LAN E2E remain green.

Rationale: PROD-3C closed the implementable auth-email queue and fail-closed guardrail work in LAN. The remaining blocker is operational: real provider apps, Vault/GitOps secret material, staging deployment mode, real SMTP delivery and staging smoke evidence.

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
