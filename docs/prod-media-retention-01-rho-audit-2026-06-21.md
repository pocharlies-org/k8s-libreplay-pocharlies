# PROD-MEDIA-RETENTION-01 RHO Rollout

## Directives
- [x] Treat the 100 generated demo images as already satisfied. Evidence: prior Brain/source docs show demo MediaAssets and variants are linked across Discover/profile/event/date/blog.
- [x] Do not enable irreversible S3 physical delete in this increment. Evidence: source `50e1d14` marks assets `PURGE_ELIGIBLE` only; no `deleteObject` call is used.
- [x] Keep legal/privacy blockers explicit. Evidence: planner blocks verification evidence, consent docs, paid/PPV references, open reports/moderation, demo media, KYC object keys, legal holds and `csam_match`.

## Acceptance Criteria
- [x] Source implementation is validated. Evidence: `pnpm typecheck`, focused web security test `25/25`, jobs tests `14/14`, media permissions `5/5`, source CI `27888886986`, Release Image `27889021579`.
- [x] Immutable images are available. Evidence: web `sha-50e1d14f0987@sha256:0bcf80e464325668d1aa263bde3485e9f668f99a319635c4d587be652b39bf9c`, worker `worker-sha-50e1d14f0987@sha256:a9bba292e637880cec2e45f78950dfab9cc8095937d084dcd646f9b75d1ec1ee`, tools `tools-sha-50e1d14f0987@sha256:d3a380a9fafceaf4abe629cf22f2e3e4e1e060b353963a8c15767ee794edc013`.
- [x] GitOps manifest is prepared. Evidence: `k8s/manifest.yaml` updates web/worker image pins and adds `Job/libreplay-db-migrate-50e1d14`.
- [ ] GitOps CI passed. Evidence: pending.
- [ ] Argo rollout and migration job completed. Evidence: pending.
- [ ] Runtime health, retention dry-run and focused E2E passed. Evidence: pending.

## Residual Risks
- [blocked] Real right-to-erasure/export workflow is still missing.
- [blocked] Version-aware S3 hard purge and orphan cleanup remain blocked by legal/versioning policy.
- [blocked] CDN/signed delivery, backup/restore rehearsal and real CSAM/media moderation providers remain production blockers.
