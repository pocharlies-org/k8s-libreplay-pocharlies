# PROD-SAFETY-MEDIA-REPORT-HOLD-01 RHO Rollout

## Directives

- [x] Keep media reporting behind auth, abuse limits and media visibility checks. Evidence: source `f6ad763` adds `POST /api/media/[id]/report` with `requireSession`, `enforceRateLimit('reports')` before body parsing/asset lookup, and `canViewMediaAsset`.
- [x] Preserve evidence instead of physically deleting media. Evidence: moderation `REMOVE_CONTENT` sets `MediaAsset.status=DELETED`, `deletedAt`, `retentionClass=LEGAL_HOLD` where safe, `purgeState=PURGE_BLOCKED`, and does not call S3 delete or write `purgedAt`.
- [x] Keep protected retention classes intact. Evidence: tests cover both `PAID_CONTENT` and `VERIFICATION_EVIDENCE` and assert `retentionClass` is not overwritten.
- [x] Do not silently restore media under legal hold. Evidence: media `RESTORE_CONTENT` returns `409 MEDIA_RESTORE_REQUIRES_REVIEW`.

## Acceptance Criteria

- [x] Source implementation is validated. Evidence: source commit `f6ad763`; local `pnpm --filter @libreplay/web test -- src/app/api/security-idor.test.ts` -> `32 passed`; `pnpm --filter @libreplay/jobs test -- src/handlers/media-retention.test.ts` -> `7 passed`; `pnpm typecheck`; `git diff --check`; source CI `27889698410` completed `success`.
- [x] Prisma migration posture is validated before deploy. Evidence: local Postgres smoke applied all `12` migrations, including `20260621033000_report_media_status_index` and `20260621033100_moderation_case_media_status_index`, via `prisma migrate deploy`.
- [x] Independent verification passed. Evidence: Mencius verified report route, legal hold, protected classes, restore block and retention blockers; Nash verified separated concurrent index migrations; Erdos verified GitOps image pins, migrate Job, no `:latest` and server dry-run.
- [x] Immutable images are available. Evidence: Release Image `27889835533` completed `success`; web `sha-f6ad7631d275@sha256:3a39aefe93a4d6c6a7def73a7ae86dc756d496ecc948ebe9438a3b9032890b8d`, worker `worker-sha-f6ad7631d275@sha256:c10548aefc111a8e0d4657ba777eecd5b5c36ba224bab57784ce0a6c72f3ffea`, tools `tools-sha-f6ad7631d275@sha256:6d2346eb59f39f3d193b36ee59e86d65e852962ca641dcd1c4a4fb1bd887db72`.
- [x] GitOps manifest is prepared and validated. Evidence: GitOps commit `7204aa6` updates web/worker image pins and adds `Job/libreplay-db-migrate-f6ad763`; server dry-run created the new Job; kustomize render had no `:latest`; GitOps CI `27890068627` completed `success`.
- [x] Argo rollout and migration completed. Evidence: Argo `libreplay` is `Synced|Healthy|7204aa656413bef80290d72a66e9bce208916c46|Succeeded`; `Job/libreplay-db-migrate-f6ad763` completed `1/1`; logs show both new migrations applied successfully.
- [x] Runtime DB and media regression gates passed. Evidence: Postgres reports indexes `ModerationCase_mediaAssetId_status_idx` and `Report_mediaAssetId_status_idx`; `/api/health/deps` returned `ok:true`; focused LAN Playwright `e2e/33-payments-media.auth.spec.ts --project=member` returned `5 passed (7.4s)`; web/worker 10-minute log greps returned no matches; web/worker pods are `1/1` on expected digests with zero restarts.

## Residual Risks

- [blocked] There is no full moderator UI for reviewing/releasing media legal holds or restoring media safely.
- [blocked] Real CSAM/media moderation providers remain missing; this gate preserves reported media and opens cases, but does not automate provider review.
- [blocked] Real right-to-erasure/export workflow, version-aware physical purge/orphan cleanup, CDN/signed delivery and backup/restore rehearsal remain production blockers.
