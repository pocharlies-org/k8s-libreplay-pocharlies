# PROD-MEDIA-CDN-LIFECYCLE-01 Media Storage Lifecycle RHO Audit

Date: 2026-06-21
Owner: PMO / DevOps / Backend-Media / Security
Status: `DEPLOYED-LAN-VALIDATED-BLOCKED-BY-CDN-RETENTION-PROVIDERS`

## Objective

Add the first production-grade media storage control that can be applied without
external provider secrets: bucket versioning plus conservative lifecycle cleanup
for noncurrent object versions and delete markers. This protects the S3-compatible
media bucket from unbounded historical object growth while avoiding automatic
deletion of current active user media before legal/product retention policy is
approved.

## Directives

- [x] Do not read or print storage credentials. Evidence: checks inspect
  manifests, Job status and audit log markers only.
- [x] Do not expire current active media objects by age in this gate. Evidence:
  the static verifier rejects `--expire-days` in the media policy Job.
- [x] Avoid mutating the completed `libreplay-minio-init` Job spec. Evidence:
  the policy is a new Job named `libreplay-minio-policy-20260621`.
- [x] Keep CDN/signed delivery and DB retention schema as explicit follow-up
  work. Evidence: residual blockers below remain open.

## Acceptance Criteria

- [x] GitOps defines an idempotent media storage policy Job. Evidence:
  `k8s/manifest.yaml` defines `Job/libreplay-minio-policy-20260621`.
- [x] Bucket versioning is enabled by GitOps. Evidence: the Job runs
  `mc version enable "${target}"`.
- [x] Lifecycle controls noncurrent versions without deleting active current
  media by age. Evidence: the Job runs `mc ilm rule add` with
  `--noncurrent-expire-days`, `--noncurrent-expire-newer` and
  `--expire-delete-marker`, and no `--expire-days`.
- [x] Static verifier exists. Evidence:
  `scripts/check-libreplay-media-storage-policy.sh --static`.
- [x] Staging runtime inherits the policy Job. Evidence: the static verifier
  renders `staging/overlays/runtime` and checks
  `Job/libreplay-minio-policy-20260621` in `libreplay-staging` targeting
  `libreplay-media-staging`.
- [x] Live bucket policy is applied in LAN. Evidence: GitOps commit
  `9848ef4 feat(media): add minio lifecycle policy gate`; GitOps CI run
  `27888429666` passed; Argo `libreplay` is
  `Synced|Healthy|9848ef458cca0c6c2c0645cea4bf0e292b8a9346|k8s`; live Job
  `libreplay-minio-policy-20260621` succeeded.

## Specialist Checks

- [x] Backend/Media subagent pass completed read-only. Evidence: Kant confirmed
  current upload, compression, video/HLS, worker and serving flows are in place,
  and identified missing CDN/signed delivery plus DB lifecycle/retention schema.
- [x] DevOps/Storage PMO pass completed. Evidence: manifest dry-run, kustomize
  render, static verifier, GitOps CI, Argo and live Job verification passed.
- [x] Independent DevOps/Storage subagent pass completed read-only. Evidence:
  James confirmed static production media contract exists, LAN MinIO/PVC are
  healthy, lifecycle/versioning was missing before this gate, CDN/backup/HA
  remain open, and recommended an idempotent MinIO policy job plus verification.

## Verification Commands

- [x] `scripts/check-libreplay-media-storage-policy.sh --static` passed.
- [x] `kubectl apply --dry-run=server -f k8s/manifest.yaml` passed, showing
  `job.batch/libreplay-minio-policy-20260621 created (server dry run)`.
- [x] `kubectl kustomize k8s` and `kubectl kustomize staging/overlays/runtime`
  render the policy Job with versioning and noncurrent lifecycle controls.
- [x] `git diff --check` passed.
- [x] GitOps CI run `27888429666` passed with no-`:latest`, YAML,
  kubeconform and Kustomize render checks.
- [x] `scripts/check-libreplay-media-storage-policy.sh --live` passed.
- [x] Live Job logs prove the policy. Evidence: MinIO reported
  `versioning is enabled`; lifecycle rule `d8rj0au5vkbs7hha9tkg` is enabled
  with delete-marker expiration, noncurrent expiration after `30` days and
  `KEEP VERSIONS=2`.
- [x] Media runtime still works after bucket policy. Evidence:
  `NODE_TLS_REJECT_UNAUTHORIZED=0 BASE_URL=https://libreplay.lan.e-dani.com
  PWRETRIES=0 pnpm --filter @libreplay/web exec playwright test
  e2e/33-payments-media.auth.spec.ts --project=member --reporter=line`
  returned `5 passed (7.1s)`.
- [x] Runtime health and logs are clean after the change. Evidence:
  `/api/health/deps` returned `ok:true`; 5-minute web and worker log scans for
  `p1001|readablestream|already closed|error|exception|failed|unhandled`
  returned no matches.

## Residual Blockers

- [blocked] No CDN/signed object delivery cutover exists. Current serving remains
  authorized first-party `/api/media` proxy with private cache headers.
- [blocked] DB-backed media retention/delete lifecycle is only partially
  closed. `MediaAsset` retention class, delete/purge timestamps and default
  dry-run planner now exist in source `50e1d14`, but physical S3 purge,
  orphan cleanup and legal/versioning sign-off remain intentionally blocked.
- [blocked] No real CSAM/media moderation providers are configured for staging
  or production.
- [blocked] No production media legal/retention policy has been approved for
  active originals, verification evidence, adult content and creator paid media.
