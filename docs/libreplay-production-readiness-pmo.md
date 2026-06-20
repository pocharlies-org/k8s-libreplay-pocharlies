# LibrePlay Production Readiness PMO

Status: `NOT-PRODUCTION-READY`
Last updated: 2026-06-20 09:23 CEST
Target today: `https://libreplay.lan.e-dani.com`

## Executive Position

LibrePlay is a validated LAN demo, not a production-ready social network.

PMO assessment: do not open this to real users until the P0/P1 gates below are closed with evidence. The LAN validation harness, critical dependency baseline, release automation, worker-backed media queue, image variant generation, video probe/thumbnail groundwork, video MP4/HLS rendition MVP, payment fail-closed/provider selection, provider-neutral payment transaction ledger scaffold, site-wide API mutation origin gate, concrete dates/posts/events/groups/paid-content/blog BOLA fixes, Redis-backed abuse/rate limiting, trusted proxy/client-IP source and staging contract gate, demo visual media content, same-origin real map tile proxy, visual media wash/verification gate, auth email recovery groundwork, OAuth/CSRF hardening, auth email queueing, redacted console auth-email logs, staging/prod SMTP/OAuth guardrails, staging mock-OAuth fail-closed policy, gated real-provider Playwright smoke definition, staging auth runbook, static staging secret contract, staging runtime overlay scaffold, staging secrets intake, pending social-email completion, authenticated mobile core coverage and the mobile Discover responsive fix are now fixed, but the app still lacks real OAuth provider runtime/secrets, production payments through an approved adult-friendly PSP, real identity/age verification providers, real CSAM/media moderation, real SMTP provider delivery in staging/prod, public trusted-proxy runtime proof for per-IP abuse budgets, full production media delivery/lifecycle/CDN controls, full mobile product matrix validation, production observability, DR rehearsal and legal/compliance sign-off.

## RHO Task Checklist

### Directives

- [x] Treat memory snippets as discovery only. Evidence: full brain reports inspected for 2026-06-18 blocker and 2026-06-19 guardrail completion.
- [x] Verify current repo and cluster state before claiming readiness. Evidence: source/GitOps `git status`, Argo, ConfigMap, pod image/env, Playwright, and `pnpm audit --prod`.
- [x] Separate LAN demo readiness from production readiness. Evidence: runtime has `DEPLOYMENT_MODE=lan-demo`, all mock flags explicitly true, and source production guardrail rejects those flags.
- [x] Record blockers without weakening acceptance criteria. Evidence: this document keeps failing or blocked items open.

### Current Acceptance Evidence

- [x] Source repo exists and is clean. Evidence: `/home/dibanez/k8s/libreplay` on `main`, head `df16891 feat(payments): add transaction ledger scaffold`.
- [x] GitOps runtime manifest is deployed and pushed. Evidence: `/home/dibanez/k8s/k8s-libreplay-pocharlies` on `deploy/prod`; current runtime manifest commit `f65342d fix: deploy libreplay payment ledger scaffold` is pushed and GitOps CI run `27864058325` completed `success`.
- [x] LAN runtime is healthy. Evidence: Argo `libreplay` is `Synced|Healthy|f65342d1c1b8090c29e02092b11f1b8143994dca`; runtime web image `sha-df168914672d@sha256:c75d9ef07b1648e9f1c307d090c0777239bfecb81b7b0c8e8db442f6f44376c2`, worker image `worker-sha-df168914672d@sha256:91d9f9c62c78c47f9899d63b4d309b8ae67e70ed3cabd547015d7f2524b4b158`.
- [x] LAN demo guardrail is active. Evidence: pod env has `DEPLOYMENT_MODE=lan-demo`, `NODE_ENV=production`, `ENABLE_LAN_DEMO_LOGIN=true`, `PAYMENT_PROVIDER=mock`, `ENABLE_MOCK_PAYMENTS=true`, `ENABLE_MOCK_LLM=true`.
- [x] Authenticated mobile core coverage exists and passes. Evidence: mobile Playwright project has `11 tests in 2 files`; final LAN mobile run returned `11 passed (10.0s)`, covering auth layout, OAuth buttons, forgot/reset/verify/social-email, bottom nav, feed publish/report, Discover filters/message, messages send, settings/security and map.
- [x] Full LAN E2E is green. Evidence: `NODE_TLS_REJECT_UNAUTHORIZED=0 BASE_URL=https://libreplay.lan.e-dani.com PWRETRIES=0 pnpm --filter @libreplay/web exec playwright test --reporter=line` -> `90 passed (1.7m)`.
- [x] Production security dependency baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found` after upgrading Next to `15.5.19`, `next-intl` to `4.13.0` and adding transitives overrides.
- [x] Auth email queue is deployed and drains. Evidence: `/api/health/deps` reports `authEmail` waiting/active/delayed/failed all `0`; worker logs show `[auth-email:password_reset] queued console delivery to=demo-member@libreplay.local` and `auth-email completed 2 password_reset` with no URL or token.
- [x] Staging can no longer pass with mock OAuth enabled at app-config level. Evidence: source commit `31b26c3`; `DEPLOYMENT_MODE=staging` requires `USE_MOCK_OAUTH=false`, Google/Facebook secrets and `OAUTH_TOKEN_ENC_KEY`.
- [x] Static staging secret/DNS contract exists and is live. Evidence: `staging/libreplay-staging-contract.yaml` defines Namespace, `ExternalSecret/libreplay-secrets`, `ExternalSecret/harbor-pull`, DNS-only `Service/libreplay-staging-dns-preflight` and `ConfigMap/libreplay-config` for `libreplay-staging`, references `secret/libreplay/staging`, validates with Kustomize client dry-run, and Argo `libreplay-staging` is `Synced|Degraded|cb2c88101b90379310841742adf2cf3e39434626|staging`.
- [x] Staging runtime overlay is prepared but not live. Evidence: `staging/overlays/runtime` renders a full `libreplay-staging` workload overlay with real auth/SMTP posture, public `traefik-edge` ingress, external-dns Cloudflare-proxied target `57.129.17.172`, public TLSStore and passes `scripts/check-libreplay-staging-runtime.sh`; it is not wired to Argo until real secrets, DNS/TLS and image pull secret handling are proven.
- [x] Staging preflight, DNS and image pull secret contracts are live. Evidence: `staging/libreplay-staging-contract.yaml` declares `ExternalSecret/harbor-pull` from `infra/harbor/ci-robot` and DNS-only `Service/libreplay-staging-dns-preflight`; `scripts/check-libreplay-staging-preflight.sh` checks app/path safety, no runtime resources, DNS preflight service shape, config posture, ExternalSecret/Secret readiness, DNS and TLS without printing secrets; post-deploy preflight reports `harbor-pull`, DNS resolution and TLS handshake OK.
- [x] Staging secret intake exists without leaking values. Evidence: [libreplay-staging-secrets-intake.md](./libreplay-staging-secrets-intake.md) maps the 18 `secret/libreplay/staging` fields, distinguishes generated internal secrets from provider-proven OAuth/SMTP credentials, records current 1Password metadata findings and includes a no-echo Vault push procedure.
- [x] Public edge can watch future staging routes. Evidence: infra commit `56da136` adds `libreplay-staging` to `traefik-edge` CRD/Ingress watched namespaces; Argo `traefik-edge` is `Synced|Healthy|40.2.0,56da136993ea209d2173d999f876af39df16b67c`; DaemonSet rollout completed with provider args containing `libreplay-staging`.
- [x] Pending OAuth email flow no longer dead-ends. Evidence: `/[locale]/auth/social-email` and `POST /api/auth/social-email` exist; pending social cookie is AES-GCM sealed, token-free and TTL-bound; manual email completion queues verification email and full LAN E2E is green.
- [x] Mobile Discover responsive bug is fixed. Evidence: first LAN mobile run on authenticated mobile coverage found the filters panel pushed `Mensaje` outside the iPhone viewport; source `8d64302` stacks Discover filters on mobile and final LAN mobile/full E2E passed.
- [x] Video MP4/HLS rendition MVP is deployed and validated. Evidence: source commit `2a04229`, migration `20260619212500_video_renditions`, Release Image run `27849982311`, GitOps commits `6437736` and `32ad2dc`, focused LAN media E2E `5 passed (7.2s)`, latest DB video asset `cmqlh6b4m000d4ozyuwcxz4ry` has `THUMB_LARGE`, `VIDEO_MP4_480P` and `VIDEO_HLS_480P`, and full LAN E2E returned `90 passed (1.5m)`.
- [x] Payment fail-closed/provider selection is deployed and validated. Evidence: source commit `d2438a0`, source CI run `27851079378`, Release Image run `27851301076`, GitOps commit `a8dbe19`, GitOps CI run `27851552472`, runtime env `PAYMENT_PROVIDER=mock` only under `DEPLOYMENT_MODE=lan-demo`, staging contract `PAYMENT_PROVIDER=disabled` with `ENABLE_MOCK_PAYMENTS=false`, webhook placeholder returns `503 PAYMENT_PROVIDER_NOT_CONFIGURED`, focused payment/media E2E returned `5 passed (7.5s)`, and full LAN E2E returned `90 passed (1.4m)`.
- [x] Provider-neutral payment transaction ledger scaffold is deployed and validated. Evidence: source commit `df16891`, source CI run `27863683843`, Release Image run `27863843341`, GitOps commit `f65342d`, GitOps CI run `27864058325`, migration job `libreplay-db-migrate-df16891` completed, DB query returned `"PaymentTransaction"`, webhook remains fail-closed with `503 PAYMENT_PROVIDER_NOT_CONFIGURED`, `/api/health/deps` is healthy, and focused LAN E2E for payment/media/demo visuals/mobile visuals returned `10 passed (13.0s)`.
- [x] Site-wide API mutation origin gate and P0 dates/posts BOLA fixes are deployed and validated. Evidence: source commit `c3ca34b`, source CI run `27852395400`, Release Image run `27852581835`, GitOps commit `1bc61b9`, GitOps CI run `27852814357`, runtime cross-site `POST /api/posts` returns `403 INVALID_ORIGIN`, runtime same-origin unauthenticated POST returns auth redirect `307`, full LAN E2E returned `90 passed (1.5m)`, and web/worker logs have no recent error matches.
- [x] Remaining concrete events/groups/paid-content/blog BOLA fixes are deployed and validated. Evidence: source commit `7a7d566`, source CI run `27853674582`, Release Image run `27853851439`, GitOps commit `458bb88`, GitOps CI run `27854062401`, runtime cross-site `POST /api/events` returns `403 INVALID_ORIGIN`, full LAN E2E returned `90 passed (1.5m)`, and web/worker logs have no recent error matches.
- [x] Redis-backed abuse/rate limiting is deployed and validated for LAN. Evidence: source commit `4be4785`, source CI run `27854730178`, Release Image run `27854887817`, GitOps commit `9215e80`, GitOps CI run `27855093322`, runtime env `RATE_LIMIT_BACKEND=redis` and `RATE_LIMIT_FAIL_MODE=closed`, invalid login smoke returned `400` for the first five attempts then `429 RATE_LIMITED` for attempts six/seven, Redis key `libreplay:rl:lan-demo:login:10.42.0.0` reached `ttl=870 value=7`, and full LAN E2E returned `90 passed (1.5m)`.
- [x] Demo visual content and real map fallback are deployed and validated. Evidence: source commits `18aeffb` and `eed2ff4`, source CI runs `27857859914` and `27858493902`, Release Image runs `27858038698` and `27858645816`, GitOps commits `2efac7f` and `177414d`, GitOps CI runs `27858269590` and `27858810665`, seed job `libreplay-db-seed-eed2ff4` completed `done 100/100`, runtime SQL reports `100` demo `MediaAsset` rows, `500` variants, `70` avatars, `10` profile covers, `8` event covers, `6` date covers and `6` demo blog covers; full LAN E2E returned `90 passed (1.7m)`.
- [x] Visual media wash and demo asset verification are deployed and validated. Evidence: visual audit subagent Godel reported all `100` generated assets linked to UI-consumed entities; source commit `006088f`, source CI run `27859754713` passed after rerun, Release Image run `27859924402` passed, GitOps commit `76cdd55`, GitOps CI run `27860101187` passed, Argo is `Synced/Healthy`, focused LAN visual E2E returned `3 passed (7.6s)`, `/api/health/deps` is healthy and 10-minute web/worker error greps returned no matches.
- [x] Trusted proxy/client-IP gate is deployed for LAN and prepared for staging. Evidence: source commit `b7cd809`, source CI run `27862537072`, Release Image run `27862689469`, GitOps commit `5937cf8`, GitOps CI run `27862856489`, Argo `libreplay` is `Synced|Healthy|5937cf81ad4ff7f6d54172df5d025eb304c07595`, live LAN config is `TRUST_PROXY_CLIENT_IP=false` with `TRUSTED_CLIENT_IP_HEADER=x-forwarded-for`, staging contract config is `TRUST_PROXY_CLIENT_IP=true` with `TRUSTED_CLIENT_IP_HEADER=cf-connecting-ip`, and full LAN E2E returned `93 passed (1.5m)`.
- [x] PROD-10A staging runtime contract gate progressed. Evidence: static contract and future runtime overlay both render and pass client dry-run; source config/auth guardrails pass; gated `staging-real-auth` project lists 2 smokes; contract-only Argo app is prepared in a clean root GitOps worktree.
- [blocked] Public trusted-proxy runtime proof remains blocked by staging secrets. Evidence: staging preflight confirms DNS/TLS, `harbor-pull` and the trusted proxy config are now OK, but `ExternalSecret/libreplay-secrets` is still `Ready=False SecretSyncedError` and `Secret/libreplay-secrets` is absent, so Cloudflare-backed runtime workloads are intentionally not live.
- [blocked] Runtime logs show an operational residual during heavy validation. Evidence: current `/api/health/deps` is healthy and full LAN E2E passed, but post-E2E log sweep captured one `ReadableStream is already closed`; earlier validation also captured transient Prisma `P1001` database reachability errors during load. Production readiness needs connection-pool/readiness/stream observability and alerting before sign-off.

## Specialist Assessment

### Product / PO

- [x] Core social surfaces exist. Evidence: 49 page routes and 118 API routes under `apps/web/src/app`; E2E covers landing, auth, feed, discover, friends, profiles, messages, dates, events, clubs, groups, forum, blog, creator, admin, media and onboarding.
- [x] LAN demo has realistic visual content across the main social surfaces. Evidence: `100` generated URL-only demo image assets were seeded through MediaAsset/S3-compatible storage and attached to Discover/profile avatars, profile covers, event covers, date covers and blog covers; runtime SQL reports `profile_avatars=70`, `profile_covers=10`, `event_covers=8`, `date_covers=6`, `demo_blog_covers=6`.
- [x] Main visual pages now reuse demo assets as subtle backgrounds instead of looking empty. Evidence: Discover, events, dates and blog wrap their first available MediaAsset URL through `.lp-media-wash`; focused LAN visual E2E validates image-backed surfaces and map tiles.
- [ ] Production onboarding is complete. Missing: real email verification, password reset email delivery, consent capture/versioning UX, abuse-safe profile review, deletion/export flows.
- [ ] A full production product definition exists. Missing: launch markets, legal age rules per country, allowed content policy, monetization policy, moderation SLA, support workflows, trust/safety escalation.
- [ ] Mobile product coverage is complete. Missing: mobile E2E for feed, discover, profile, messages, upload, verification, settings, reports, creator checkout and admin/moderation.

### Frontend / Mobile

- [x] Mobile smoke for auth shell/auth recovery passes. Evidence: mobile Playwright project, iPhone-like viewport, 5 tests passing for auth layout, OAuth button tap targets, forgot/reset/verify/social-email routes and landing CTA.
- [x] Authenticated mobile core coverage passes. Evidence: `16-mobile-auth.mobile.spec.ts` validates bottom nav, feed publish/report, Discover filters/message, messages send, settings/security and map on the mobile project; final LAN mobile run returned `11 passed`.
- [x] Mobile responsive regression was fixed from test evidence. Evidence: Discover filters initially failed by pushing `Mensaje` outside viewport; `lp-discover-main.with-filters` now stacks below `900px`; final full LAN E2E returned `90 passed`.
- [x] Mobile map and image-heavy core flow pass in LAN. Evidence: full LAN Playwright includes `map mobile flow can request nearby profiles without covering controls`, Discover filters/message mobile flow and blog/events/date surface coverage; final run returned `90 passed (1.7m)`.
- [x] Visual media backgrounds have a focused regression gate. Evidence: `e2e/34-demo-visuals.auth.spec.ts` checks `/es/discover`, `/es/events`, `/es/dates`, `/es/blog` for image-backed `.lp-media-wash` surfaces and `/es/map` for same-origin real map tiles; deployed LAN run returned `3 passed`.
- [ ] PWA/mobile app readiness exists. Missing: installability, safe-area handling, touch gestures for swipe, file capture from camera, mobile upload progress, offline/error states, Android/iOS cross-browser validation.
- [ ] Full mobile product matrix coverage exists. Missing: mobile upload/camera capture, verification UX, creator checkout, admin/moderation, payments edge cases and real-device browser matrix.
- [ ] Accessibility baseline is complete. Missing: automated a11y checks, keyboard flows, screen-reader labels for custom controls, contrast audit across dark UI.

### Backend / Auth

- [x] Credentials and OAuth architecture exists. Evidence: `packages/auth/src/providers/google.ts`, `facebook.ts`, `oauth.ts`, encrypted token fields in `AuthAccount`.
- [x] Email verification/password reset groundwork exists. Evidence: source commit `1bbe568`; DB has `EmailVerificationToken` and `PasswordResetToken`; forgot/reset/verify/register routes are wired; forgot-password remains non-enumerating; auth package tests cover token hashing/expiry and email provider posture; focused auth E2E is `6 passed`.
- [x] OAuth mock/token guardrails improved. Evidence: mock OAuth providers are limited to test/development/LAN demo; staging/production missing credentials return provider disabled; OAuth token encryption fails closed in staging/production without `OAUTH_TOKEN_ENC_KEY`; pending-social cookie does not store provider tokens.
- [x] OAuth protocol and account-linking hardening exists before real-provider staging. Evidence: source commit `c37cdca`; Google uses PKCE S256, nonce and `id_token` issuer/audience/nonce validation; Facebook sends documented plain PKCE and does not auto-verify Graph email; OAuth flow metadata is sealed with AES-GCM, scoped by provider+state and TTL; linking is bound to initiating session/user and handles provider/email conflicts plus P2002 races; auth tests are `20 passed`.
- [x] Pending OAuth email completion exists. Evidence: source commit `783bb8d`; callback stores token-free pending profiles in a sealed TTL cookie, `/auth/social-email` collects a manual email, `/api/auth/social-email` enforces origin/rate/session/pending-cookie checks, creates social account in a transaction, queues email verification and handles P2002 races as conflicts.
- [x] Sensitive auth/account mutation routes enforce browser request origin checks. Evidence: central `enforceAuthOrigin` uses Origin, Referer and Fetch Metadata; focused LAN auth E2E is `7 passed` including cross-site rejection for login/forgot/reset/verify/logout/unlink-social; web/security tests cover production fail-closed and LAN compatibility.
- [x] Site-wide browser-origin gate covers non-auth API mutations. Evidence: source commit `c3ca34b`; middleware matches `/api/:path*`, checks all `POST|PUT|PATCH|DELETE` routes with Origin/Referer/Fetch Metadata, rejects cross-site fetch metadata, and exempts only `/api/payments/webhook`; runtime cross-site `POST /api/posts` returned `403 INVALID_ORIGIN`.
- [blocked] Real Google/Facebook login is not enabled in LAN/prod. Evidence: ConfigMap still has `USE_MOCK_OAUTH=true`; live secret keys do not include `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `FACEBOOK_CLIENT_ID`, `FACEBOOK_CLIENT_SECRET` or `OAUTH_TOKEN_ENC_KEY`.
- [x] Auth email queue/retry groundwork exists. Evidence: source commit `9670441 feat(auth): queue transactional emails`; `register` and `forgot-password` enqueue `auth-email` jobs, worker processes auth email separately from media, `/api/health/deps` exposes queue counts, and completed jobs are removed immediately.
- [x] Console auth-email logging is redacted. Evidence: source commit `53a8b48 fix(auth): redact console email action urls`; final worker logs contain recipient and job metadata only, and `rg 'token=|url=|reset-password|verify-email|password-reset|actionUrl'` against recent worker logs found no matches.
- [x] Real-provider staging smoke is defined without weakening LAN suite. Evidence: source commit `31b26c3` adds gated Playwright project `staging-real-auth`; default LAN suite remains `79 tests`, gated staging list is `81 tests` only when `PW_STAGING_REAL_AUTH=1`.
- [x] Real-provider staging runtime manifest is prepared. Evidence: `staging/overlays/runtime` renders `DEPLOYMENT_MODE=staging`, `USE_MOCK_OAUTH=false`, required Google/Facebook/OAuth/SMTP Secret refs, SMTP email provider, disabled mock payments and staging host `libreplay-staging.e-dani.com`; checker rejects LAN-only drift.
- [blocked] Real Google/Facebook staging is not live yet. Evidence: contract-only Argo app/namespace/ExternalSecrets/DNS for `libreplay-staging` now exist and DNS/TLS preflight is OK, but `ExternalSecret/libreplay-secrets` is `Ready=False SecretSyncedError` because `secret/libreplay/staging` provider data is missing; no proven LibrePlay-specific Google/Facebook/OAuth/SMTP Vault values exist, adjacent 1Password candidates are not sufficient to authorize reuse, and real-provider Playwright smoke has only been listed, not executed.
- [blocked] Email auth is not production-grade yet. Evidence: token flows and queue/retry groundwork exist, but real SMTP secrets/runtime, real provider delivery, staging smoke, delivery observability, support recovery workflow and abuse controls are still absent.
- [ ] Auth session hardening is complete. Missing: session rotation policy, device/session management UI, 2FA/passkeys, suspicious login alerting.

### Payments / Monetization

- [blocked] Stripe is not a safe default assumption for this product. Evidence: official Stripe restricted-business docs list adult services, pay-per-view adult features, adult live chat and mature audience sexual content as restricted/prohibited; Stripe may require explicit approval or may not support the business.
- [x] Payment domain scaffolding exists. Evidence: `Purchase`, `CreatorSubscription`, `PaidContentPurchase`, `CreatorMembership`, provider interface, mock payment provider and env-selected payment provider facade.
- [x] Provider-neutral transaction ledger scaffold exists. Evidence: source worktree adds `PaymentTransactionKind`, `PaymentTransaction`, migration `20260620090000_payment_transaction_ledger` and `apps/web/src/lib/payment-transactions.ts` for pending transactions plus idempotent webhook completion; focused tests pass.
- [x] Mock payments fail closed outside LAN/test. Evidence: `PAYMENT_PROVIDER` defaults to `disabled`; staging/prod reject `PAYMENT_PROVIDER=mock` or `ENABLE_MOCK_PAYMENTS=true`; six mock purchase routes return `503 PAYMENT_PROVIDER_NOT_CONFIGURED` before session/DB work when disabled; webhook placeholder returns `503` until a real PSP exists.
- [blocked] Real payments are not integrated. Evidence: no approved PSP package/env exists; no signed external webhook verification, checkout session route, refunds, disputes, subscription lifecycle, tax/VAT or creator payout/KYC flow is implemented; the ledger scaffold is not a live PSP.
- [ ] Adult-friendly PSP decision exists. Missing: compliance-approved PSP, marketplace/payout/KYC model, webhook idempotency, chargeback/refund/negative-balance handling, tax/VAT handling.

### Media / S3 / Compression

- [x] S3-compatible storage path exists. Evidence: `packages/media/src/s3.ts`, first-party upload endpoint, private MinIO deployment, `MediaAsset`/`MediaVariant` schema.
- [x] Scalable media queue foundation exists. Evidence: `/api/media/complete` validates S3 object metadata, enqueues BullMQ only, has no inline processing fallback, and `Deployment/libreplay-worker` is running `1/1` with Redis wait/failed queues at `0`.
- [x] Image compression/variants are implemented for LAN runtime. Evidence: source commit `282d735`; worker uses `sharp` to generate WebP/AVIF thumbnails and blurred preview; DB has five `MediaVariant` rows for test asset `cmql2t9ll002htbd0mkoperbu`; MinIO `mc stat` confirms original plus five variant objects with non-zero sizes and correct content types.
- [x] Video probe/thumbnail groundwork is implemented for LAN runtime. Evidence: source commits `a55c0f6` and `e9a1135`; Release Image run `27836030980`; GitOps commit `e576d68`; worker runtime has `ffmpeg`/`ffprobe` `5.1.9`; focused media Playwright `5 passed`; DB asset `cmql4l8dw000d31zblcy4a08a` has `durationSeconds=1`, `width=16`, `height=16`, and `THUMB_LARGE image/jpeg` variant; MinIO confirms original `video/mp4` and thumbnail `image/jpeg` objects.
- [x] Video MP4/HLS rendition MVP is implemented for LAN runtime. Evidence: source commit `2a04229`; worker creates `VIDEO_MP4_480P video/mp4` and `VIDEO_HLS_480P application/vnd.apple.mpegurl`; variant route enforces viewer authorization and supports MP4 byte ranges; focused LAN media E2E `5 passed`; DB asset `cmqlh6b4m000d4ozyuwcxz4ry` contains thumbnail, MP4 480p and HLS variants.
- [x] Demo images are served through the first-party media/variant pipeline. Evidence: source commit `18aeffb`; `/api/media/[id]?variant=...` supports approved variants; runtime has `100` demo media assets and `500` generated variants; UI surfaces use media IDs instead of committed binary images.
- [x] First-party demo media streaming has a visual regression gate. Evidence: `e2e/34-demo-visuals.auth.spec.ts` fetches `/api/media/{id}?variant=THUMB_LARGE`, verifies image content type and non-empty bodies, and the deployed LAN run passed.
- [blocked] Production media delivery is not complete. Evidence: one 480p MP4/HLS rendition is validated, but production still lacks a bitrate ladder, CDN/signed delivery strategy, async progress UI, lifecycle/retention policy, failure replay/dead-letter runbook, real CSAM/media moderation providers and multi-replica worker scaling.
- [ ] Durable media lifecycle exists. Missing: original/variant retention rules, object lifecycle policies, AV scanning, hash dedupe, CDN strategy, backup/restore, orphan cleanup.
- [ ] Video scalability exists. Missing: bitrate ladder beyond 480p, CDN strategy, async job progress UI, retention/lifecycle policies, failure replay and production worker scaling.

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
- [x] Release automation remains complete for video renditions/HLS. Evidence: source CI run `27849729670` and Release Image run `27849982311` completed `success`; GitOps commits `6437736` and `32ad2dc` deploy web/worker/tools digests for source `2a04229`; GitOps CI runs `27850274935` and `27850375820` completed `success`; migration job `libreplay-db-migrate-2a04229` completed; Argo is `Synced/Healthy`; full LAN E2E is `90 passed`.
- [x] Release automation remains complete for payment fail-closed. Evidence: source CI run `27851079378` and corrected Release Image run `27851301076` completed `success`; GitOps commit `a8dbe19` deploys web/worker digests for source `d2438a0`; GitOps CI run `27851552472` completed `success`; Argo is `Synced/Healthy`; runtime health is OK; full LAN E2E is `90 passed`.
- [x] Release automation remains complete for security mutation gate. Evidence: source CI run `27852395400` and Release Image run `27852581835` completed `success`; GitOps commit `1bc61b9` deploys web/worker digests for source `c3ca34b`; GitOps CI run `27852814357` completed `success`; Argo is `Synced/Healthy`; runtime health is OK; full LAN E2E is `90 passed`.
- [x] Release automation remains complete for remaining BOLA/IDOR guards. Evidence: source CI run `27853674582` and Release Image run `27853851439` completed `success`; GitOps commit `458bb88` deploys web/worker digests for source `7a7d566`; GitOps CI run `27854062401` completed `success`; Argo is `Synced/Healthy`; runtime health is OK; full LAN E2E is `90 passed`.
- [x] Release automation remains complete for demo visuals and real map. Evidence: source CI `27857859914`/Release Image `27858038698` passed for `18aeffb`; source CI `27858493902`/Release Image `27858645816` passed for `eed2ff4`; GitOps CI `27858269590` and `27858810665` passed; Argo is `Synced/Healthy` at `177414d`; seed job `libreplay-db-seed-eed2ff4` completed.
- [x] Release automation remains complete for visual media wash. Evidence: source CI run `27859754713` passed after rerun; Release Image run `27859924402` completed `success`; GitOps commit `76cdd55` deploys web/worker digests for source `006088f`; GitOps CI run `27860101187` completed `success`; Argo is `Synced/Healthy`; focused LAN visual E2E is `3 passed`.
- [x] Release automation remains complete for auth email recovery. Evidence: source CI run `27837492921` completed `success`; Release Image run `27837784400` completed `success`; GitOps commit `da4868b` deploys web/worker/tools digests for source `1bbe568`; GitOps CI run `27838078792` completed `success`; migration job `libreplay-db-migrate-1bbe568` completed; Argo is `Synced/Healthy`.
- [x] Release automation remains complete for OAuth/CSRF hardening. Evidence: source CI run `27839801643` completed `success`; Release Image run `27840087320` completed `success`; GitOps commit `a3a6567` deploys web/worker/tools digests for source `c37cdca`; GitOps CI run `27840418461` completed `success`; migration job `libreplay-db-migrate-c37cdca` completed; Argo is `Synced/Healthy`.
- [x] Release automation remains complete for auth email queue/redaction. Evidence: source CI run `27842739635` completed `success`; Release Image run `27843010658` completed `success`; GitOps commit `6ca7ede` deploys web/worker digests for source `53a8b48`; GitOps CI run `27843274783` completed `success`; Argo is `Synced/Healthy`.
- [x] Release/deploy evidence is complete for staging auth gate source. Evidence: source CI run `27844167141` and Release Image run `27844447288` completed `success`; GitOps commit `1b8ff18` deploys web/worker digests for source `31b26c3`; GitOps CI run `27844721752` completed `success`; Argo is `Synced/Healthy`; full LAN E2E is `79 passed`; `/api/health/deps` is healthy with authEmail/mediaModeration queues all `0`.
- [x] Release/deploy scaffold is prepared for contract-only staging. Evidence: root GitOps worktree renders `Application/libreplay-staging` targeting path `staging`; live sync remains pending until the app-of-apps commit is pushed and Argo reconciles it.
- [blocked] Production scale/HA is missing. Evidence: GitOps now has web plus worker, but still runs single replicas for web, worker, Postgres, Redis, Meili and MinIO; no HPA, PDB, NetworkPolicy, backup CronJobs or restore rehearsal.
- [blocked] Runtime connection/readiness observability is not production-grade. Evidence: PROD-9A LAN E2E passed and health recovered, but web logs recorded transient Prisma `P1001` reachability errors during the load window; production needs dashboards/alerts for DB connection errors, connection-pool saturation and readiness failure rate.
- [ ] Observability is production-grade. Missing: metrics, dashboards, structured logs, error tracking, alerting, SLOs, synthetic checks.
- [ ] Disaster recovery is rehearsed. Missing: backup jobs, restore runbook, RPO/RTO targets, tested restore for Postgres/MinIO/Meili/Redis.

### Security

- [x] Basic security headers exist. Evidence: HTTP response includes `permissions-policy`, `referrer-policy`, `x-content-type-options`, `x-frame-options`.
- [x] Dependency security baseline is clean for known npm advisories. Evidence: `pnpm audit --prod` -> `No known vulnerabilities found`.
- [x] Auth/OAuth CSRF and Origin hardening exists. Evidence: source commit `c37cdca`; sensitive auth/account POST routes call central Origin/Fetch Metadata checks before mutation/rate-limit; production/staging fail closed without trusted Origin/Referer; LAN/dev remains compatible with API clients that omit Origin; focused and full LAN E2E pass.
- [x] Mock payment mutation routes fail closed outside LAN/test. Evidence: source commit `d2438a0`; staging/prod config rejects mock payments; all six mock purchase routes return `503 PAYMENT_PROVIDER_NOT_CONFIGURED` before session/DB work in staging-disabled tests; PPV purchase now goes through the payment provider facade.
- [x] Site-wide non-auth API mutation Origin/Fetch Metadata gate exists. Evidence: source commit `c3ca34b`; `docs/security-mutation-inventory.md` records 82 mutating route files and 86 handlers; middleware protects all API mutations except exact `/api/payments/webhook`; source and runtime tests verify cross-site rejection.
- [x] P0 dates/posts BOLA fixes exist. Evidence: `canViewDateProposal` guards date detail/apply; `canViewPost` guards post detail/react/comments/bookmark/report; `security-idor.test.ts` rejects private date and private post access before write side effects.
- [x] Remaining concrete BOLA fixes exist for events, groups, paid-content and blog attribution. Evidence: source commit `7a7d566`; `canViewEvent` and `canViewGroup` guard API and SSR detail surfaces; event listings filter `PUBLISHED + PUBLIC_VERIFIED`; paid-content verifies `postId` ownership and non-deletion; blog submit verifies `clubProfileId` ownership/admin; `security-idor.test.ts` covers no-side-effect negative paths.
- [x] Distributed rate limiting exists for app-level abuse budgets. Evidence: source commit `4be4785`; staging/production env validation requires `RATE_LIMIT_BACKEND=redis` and `RATE_LIMIT_FAIL_MODE=closed`; auth/social/media/map/AI/payment/creator/event mutation routes call named budgets; runtime login abuse smoke hits Redis-backed `429`.
- [x] Demo media cover access no longer introduces the audited cover IDOR. Evidence: `canViewMediaAsset` revalidates attached Profile/Event/DateProposal/BlogArticle visibility before serving AVATAR/COVER assets; tests reject private date covers and allow public event covers.
- [blocked] Public client-IP attribution is not runtime-proven yet. Evidence: source/GitOps now enforce an explicit trusted proxy policy and staging is configured for Cloudflare `cf-connecting-ip` plus source allowlist, but live LAN smoke still keys login by Traefik/cluster IP `10.42.0.0`; public proof requires the Cloudflare-backed staging runtime after real secrets exist.
- [blocked] Double-submit CSRF/token posture is still incomplete. Evidence: site-wide Origin/Fetch Metadata is deployed, but browser double-submit token rollout and shared client API wrapper remain pending.
- [blocked] BOLA/IDOR security review is not complete. Evidence: dates/posts/events/groups/paid-content/blog concrete issues are fixed, but creator purchases/subscriptions, album grants, admin object scopes, map/location shares and a complete route-by-route authorization matrix still need independent coverage before production.
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
- [x] Add source-level real-provider staging gates.
  Evidence: source commit `31b26c3` adds staging fail-closed env policy, config/auth/web tests, gated Playwright `staging-real-auth` project, `40-real-auth.staging.spec.ts`, and E2E docs; local gates `pnpm test`, `pnpm typecheck`, `pnpm --filter @libreplay/web build`, `pnpm audit --prod`, default Playwright list `79 tests`, gated list `81 tests` all pass.
- [x] Add staging runtime overlay and contract-only Argo app scaffold.
  Evidence: `staging/overlays/runtime` passes anti-LAN checker and client dry-run; root GitOps worktree adds `Application/libreplay-staging` targeting `path=staging` and root client dry-run passes.
- [x] Add payment fail-closed/provider selection.
  Evidence: source commit `d2438a0`, source CI run `27851079378`, Release Image run `27851301076`, GitOps commit `a8dbe19`, GitOps CI run `27851552472`, staging contract disables mock payments, LAN runtime keeps `PAYMENT_PROVIDER=mock` only under `DEPLOYMENT_MODE=lan-demo`, webhook placeholder returns `503`, focused payment/media E2E is `5 passed`, and full LAN E2E is `90 passed`.
- [x] Add site-wide API mutation Origin/Fetch Metadata gate and first P0 BOLA fixes.
  Evidence: source commit `c3ca34b`, source CI run `27852395400`, Release Image run `27852581835`, GitOps commit `1bc61b9`, GitOps CI run `27852814357`, runtime cross-site mutation smoke returns `403`, runtime webhook placeholder returns `503`, Argo is `Synced/Healthy`, and full LAN E2E is `90 passed`.
- [x] Close remaining concrete events/groups/paid-content/blog BOLA gaps.
  Evidence: source commit `7a7d566`, source CI run `27853674582`, Release Image run `27853851439`, GitOps commit `458bb88`, GitOps CI run `27854062401`, runtime image digests match Harbor, runtime health/logs are clean, and full LAN E2E is `90 passed`.
- [x] Add Redis-backed distributed rate limiting and route abuse budgets.
  Evidence: source commit `4be4785`, source CI run `27854730178`, Release Image run `27854887817`, GitOps commit `9215e80`, GitOps CI run `27855093322`, runtime env has `RATE_LIMIT_BACKEND=redis` and `RATE_LIMIT_FAIL_MODE=closed`, invalid login smoke returns `429` after budget exhaustion, Redis key evidence was captured and cleaned, and full LAN E2E is `90 passed`.
- [x] Add demo visual content and a same-origin real map tile fallback.
  Evidence: source commits `18aeffb` and `eed2ff4`, source CI runs `27857859914` and `27858493902`, Release Image runs `27858038698` and `27858645816`, GitOps commits `2efac7f` and `177414d`, GitOps CI runs `27858269590` and `27858810665`, runtime seed `libreplay-db-seed-eed2ff4` completed `100/100`, runtime SQL reports `100` demo media assets and `500` variants, CSP avoids browser OSM domains, and full LAN E2E is `90 passed`.
- [x] Add visual media wash and focused demo asset verification.
  Evidence: source commit `006088f`, Release Image run `27859924402`, GitOps commit `76cdd55`, runtime DB reports `100` demo/prod-9a assets and `500` variants, `/api/health/deps` is healthy, and focused LAN visual E2E is `3 passed`.
- [x] Add trusted proxy/client-IP gate for public abuse budgets.
  Evidence: source commit `b7cd809`, source CI run `27862537072`, Release Image run `27862689469`, GitOps commit `5937cf8`, GitOps CI run `27862856489`, runtime LAN config is explicit, staging contract uses `cf-connecting-ip` behind a Cloudflare source allowlist, and full LAN E2E is `93 passed`.

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
- [x] Add gated real-provider staging smoke definition.
  Evidence: `PW_STAGING_REAL_AUTH=1` exposes project `staging-real-auth`; it asserts Google redirects to `accounts.google.com`, Facebook redirects to `facebook.com`, and registration verification email drains `authEmail` without failures.

### P1 - Payments

- [ ] Decide PSP for adult/social product before coding Stripe as default.
  Evidence required: written PSP approval or selected adult-friendly PSP contract/technical docs.
- [x] Add payment provider abstraction selected by env and fail closed outside LAN/test.
  Evidence: `PAYMENT_PROVIDER=disabled|mock`; staging/prod reject mock provider; six mock routes return `503 PAYMENT_PROVIDER_NOT_CONFIGURED` when disabled; PPV purchase no longer writes completed access without a provider charge result.
- [x] Add provider-neutral transaction ledger scaffold.
  Evidence: `PaymentTransaction` schema/migration is deployed, `libreplay-db-migrate-df16891` completed, runtime DB exposes `"PaymentTransaction"`, and helper tests cover pending creation, webhook completion and duplicate webhook idempotency.
- [ ] Integrate the selected real PSP.
  Evidence required: webhook idempotency, signed webhook verification, refunds, subscription lifecycle, purchase access tests, dispute handling and failure-state reconciliation.
- [ ] Add creator payout/KYC flow.
  Evidence required: onboarding/KYC status in DB/UI, payout readiness gates, revenue ledger tests.

### P1 - Media

- [x] Add video probe/thumbnail/max-duration groundwork.
  Evidence: source commits `a55c0f6` and `e9a1135`; worker uses `ffprobe`/`ffmpeg` with timeouts; video upload E2E generated `THUMB_LARGE image/jpeg`; DB/S3 evidence recorded for asset `cmql4l8dw000d31zblcy4a08a`.
- [x] Add video MP4/HLS rendition MVP.
  Evidence: source commit `2a04229`; worker creates `VIDEO_MP4_480P` and `VIDEO_HLS_480P`; authorized variant route supports MP4 byte ranges and HLS playlist/segments; focused LAN media E2E `5 passed`; full LAN E2E `90 passed`.
- [ ] Complete production media delivery/lifecycle pipeline.
  Evidence required: bitrate ladder beyond 480p, CDN/signed delivery strategy, async job progress, lifecycle/retention policy, production worker scaling and failure replay/dead-letter plan.
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

`PROD-10A-REAL-AUTH-SMTP-STAGING-GATE`

Objective: stand up a non-LAN staging runtime with real Google/Facebook OAuth and real SMTP delivery enabled, with mocks fail-closed, secrets present through GitOps/Vault, and gated Playwright smokes proving provider redirects and transactional email delivery.

Success criteria:

- [ ] Create/validate staging GitOps overlay or runtime with `DEPLOYMENT_MODE=staging`, `USE_MOCK_OAUTH=false`, `AUTH_EMAIL_PROVIDER=smtp`, mock payments disabled and LAN demo login disabled.
- [ ] Ensure Google/Facebook OAuth credentials plus `OAUTH_TOKEN_ENC_KEY` and SMTP secrets exist in Vault/ExternalSecret without exposing secret values in logs/docs.
- [ ] Run gated real-provider Playwright smoke `PW_STAGING_REAL_AUTH=1` against staging and prove Google/Facebook redirects, callback failure modes and account-link conflicts are safe.
- [ ] Run SMTP delivery smoke for register/forgot-password/verify email with queue drain, redacted logs and no token-bearing completed jobs.
- [ ] Verify staging health, queues, logs, CSP, rate-limit posture and rollback path after deploy.
- [ ] Re-audit auth/session/security residual risks and only then prepare the PSP/payment-provider decision gate.

Rationale: PROD-10B closes demo realism consumption, subtle visual polish and map credibility for LAN. The next highest production blocker is provider truth: Google/Facebook login and real email delivery must work in staging before payments, public onboarding or creator monetization can be trusted. Stripe remains a blocked assumption for this product until an adult-friendly PSP decision is documented.

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
