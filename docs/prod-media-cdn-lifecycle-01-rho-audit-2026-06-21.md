# PROD-MEDIA-CDN-LIFECYCLE-01 Media Storage Lifecycle RHO Audit

Date: 2026-06-21
Owner: PMO / DevOps / Backend-Media / Security
Status: `IMPLEMENTED-PENDING-LIVE-DEPLOY`

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
- [blocked] Live bucket policy is applied in LAN. Blocker: GitOps commit is not
  deployed yet in this document revision.

## Specialist Checks

- [x] Backend/Media subagent pass completed read-only. Evidence: Kant confirmed
  current upload, compression, video/HLS, worker and serving flows are in place,
  and identified missing CDN/signed delivery plus DB lifecycle/retention schema.
- [x] DevOps/Storage PMO pass completed. Evidence: manifest dry-run, kustomize
  render and static verifier passed locally before commit.
- [blocked] Independent DevOps/Storage subagent pass is still pending. Blocker:
  subagent had not returned before this document revision.

## Verification Commands

- [x] `scripts/check-libreplay-media-storage-policy.sh --static` passed.
- [x] `kubectl apply --dry-run=server -f k8s/manifest.yaml` passed, showing
  `job.batch/libreplay-minio-policy-20260621 created (server dry run)`.
- [x] `kubectl kustomize k8s` and `kubectl kustomize staging/overlays/runtime`
  render the policy Job with versioning and noncurrent lifecycle controls.
- [x] `git diff --check` passed.
- [blocked] `scripts/check-libreplay-media-storage-policy.sh --live` is pending
  until Argo creates and completes the Job.

## Residual Blockers

- [blocked] No CDN/signed object delivery cutover exists. Current serving remains
  authorized first-party `/api/media` proxy with private cache headers.
- [blocked] No DB-backed media retention/delete lifecycle exists. Missing:
  `MediaAsset` retention class, delete/purge timestamps, purge worker, dry-run
  report, S3 delete of originals/variants and orphan cleanup.
- [blocked] No real CSAM/media moderation providers are configured for staging
  or production.
- [blocked] No production media legal/retention policy has been approved for
  active originals, verification evidence, adult content and creator paid media.
