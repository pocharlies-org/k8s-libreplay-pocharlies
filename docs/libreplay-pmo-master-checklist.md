# LibrePlay PMO Master Checklist

Status: `BLOCKED-STAGING-GATES`
Last updated: 2026-06-18

## Directives

- [x] No tocar produccion, PVCs, datos ni secrets sin aprobacion. Evidence: no `kubectl apply`, `kubectl scale`, secret edit, PVC/data mutation or workload start was executed; all runtime changes stayed in git/manifests and dry-run checks.
- [x] No usar memoria como evidencia unica. Evidence: Brain search returned no actionable match in this session; repo, Harbor and cluster state were verified with commands.
- [x] Mantener workloads dormidos. Evidence: GitOps keeps all Deployments/StatefulSets at `replicas: 0`; live cluster shows all workloads `0/0`, no pods/endpoints, and migration/seed Jobs `Suspended`.
- [x] Prohibir `latest` in GitOps. Evidence: `.github/workflows/ci.yml` has `no-latest-images`; `grep -RInE 'image: .+:latest($|[[:space:]])' k8s` returned no matches.
- [x] Registrar evidencia de source, imagen, GitOps y blockers. Evidence: this file plus commits and image digests below.
- [x] Finalizar con estado explicito. Evidence: status is `BLOCKED-STAGING-GATES`.

## Phase 0 - PMO Setup

- [x] Create checklist master. Evidence: `docs/libreplay-pmo-master-checklist.md`.
- [x] Identify repos and paths. Evidence: source repo `/home/dibanez/k8s/libreplay`; GitOps repo `/home/dibanez/k8s/k8s-libreplay-pocharlies`; Argo app lives in `/home/dibanez/k8s/k8s-gitops-pocharlies/apps/libreplay.yaml`.
- [x] Confirm standby cluster. Evidence: live `libreplay-web` had `replicas=0` and image `harbor.e-dani.com/homelab/libreplay-web:latest` before GitOps commit; no pods were started.

## Phase 1 - Source Control

- [x] Version source as private repo. Evidence: GitHub repo `pocharlies/libreplay`, branch `main`, final source commit `c275fb3`.
- [x] Exclude local/secrets/build artifacts. Evidence: `.gitignore` and `.dockerignore` exclude `.env*`, `.next`, `node_modules`, auth state, reports and local data directories.
- [x] Preserve source copy provenance. Evidence: source was copied from `sauvage:/home/ubuntu/sauvage` to `/home/dibanez/k8s/libreplay` before git initialization.

## Phase 2 - Build / CI

- [x] Add Next standalone Dockerfile. Evidence: `/home/dibanez/k8s/libreplay/Dockerfile` builds `runner` target for web.
- [x] Add migration tools target. Evidence: Dockerfile `tools` target is migration-only with Prisma CLI and `packages/db/prisma`; seed is not bundled.
- [x] Add CI workflow. Evidence: `.github/workflows/ci.yml` runs install, Prisma generate, typecheck, tests, web build and Docker target smoke builds.
- [x] Add release workflow. Evidence: `.github/workflows/release.yml` pushes web tags and `tools-*` tags to Harbor repo `homelab/libreplay-web`.
- [blocked] GitHub Actions completion. Blocker: ARC/GitHub runs were queued during this session; local gates and manual Harbor push were used as evidence instead.

## Phase 3 - Local Verification

- [x] `pnpm typecheck`. Evidence: exited 0.
- [x] `pnpm test`. Evidence: exited 0; config 4 tests, security 7 tests, auth no-tests pass, web 5 tests.
- [x] `pnpm --filter @libreplay/web build`. Evidence: exited 0 and produced Next route manifest including `/api/health`.
- [x] Docker web build. Evidence: `docker build --target runner` for final tag exited 0.
- [x] Docker tools build. Evidence: `docker run --rm --entrypoint sh libreplay-tools:ci -lc 'whoami && test -f packages/db/prisma/schema.prisma && test -d packages/db/prisma/migrations && prisma --version'` exited 0 as user `libreplay`.

## Phase 4 - Images / Harbor

- [x] Web image pushed with immutable tag and digest. Evidence: `harbor.e-dani.com/homelab/libreplay-web:sha-c275fb3@sha256:541f9b468f72cc81c5cc93cc0821ee9630a20052cc2e7d08b0a11c8872ff3c9b`.
- [x] Migration tools image pushed with immutable tag and digest. Evidence: `harbor.e-dani.com/homelab/libreplay-web:tools-sha-c275fb3@sha256:27a897c20e184f276ef701512083d464fb4731af0243816bf9995583e8749630`.
- [x] Image labels match source. Evidence: `skopeo inspect` shows `org.opencontainers.image.revision=c275fb3` and source `https://github.com/pocharlies/libreplay` for both tags.
- [x] Avoid separate tools repository. Evidence: pushing `homelab/libreplay-tools` hit Harbor `413 Payload Too Large`; release workflow now publishes tools tags inside `homelab/libreplay-web`.

## Phase 5 - GitOps

- [x] Pin web image by digest. Evidence: `k8s/manifest.yaml` and live Deployment use `sha-c275fb3@sha256:541f9b...`.
- [x] Add `imagePullSecrets`. Evidence: web and manual Jobs reference `harbor-pull`.
- [x] Align env var names with `packages/config/src/env.ts`. Evidence: ConfigMap uses `MEILISEARCH_HOST`, URL-form `MINIO_ENDPOINT`, `AUTH_URL`, locale and mock flags; app secrets use explicit `secretKeyRef`.
- [x] Add suspended migration Job. Evidence: `libreplay-db-migrate` uses tools digest and `suspend: true`.
- [x] Add suspended seed placeholder Job. Evidence: `libreplay-db-seed` is `suspend: true` and intentionally exits with a blocker message if unsuspended.
- [x] Validate manifest schema/policy without live conflicts. Evidence: namespace-rewritten `kubectl apply --dry-run=server -f -` against `default` exited 0.
- [x] Validate live web replacement path. Evidence: extracting `libreplay-web` Deployment and running `kubectl replace --dry-run=server -f -` exited 0.
- [x] Argo sync reached desired GitOps revision. Evidence: Application `argocd/libreplay` is `Synced`, revision `06d9f0e06e36dab2b90a3bb9a698f52c016f54de`, operation `Succeeded`.
- [x] Argo health reflects suspended Jobs, not a running outage. Evidence: Application health is `Suspended`; live Jobs `libreplay-db-migrate` and `libreplay-db-seed` are intentionally `suspend: true`.
- [blocked] Plain live `kubectl apply --dry-run=server -f k8s/manifest.yaml`. Blocker: existing live Deployment lacks `last-applied` and client-side apply merges old `value` with new `valueFrom`; resource is annotated `argocd.argoproj.io/sync-options: Replace=true` for Argo.
- [blocked] `harbor-pull` secret readiness. Blocker: namespace currently lacks `harbor-pull`; no secret was created by this session.
- [blocked] Runtime secret contract readiness. Blocker: live `libreplay-secrets` currently exposes only `DB_PASSWORD`, `DB_USER`, `MEILI_MASTER_KEY`, `MINIO_ROOT_PASSWORD`, `MINIO_ROOT_USER`; required app keys like `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MEILISEARCH_API_KEY` are not present yet.

## Phase 6 - Runtime / Data

- [blocked] Scale-up. Blocker: not authorized; secrets, pull secret, data migration and seed approval are incomplete.
- [blocked] DB migration execution. Blocker: backups/counts/checksums and approval missing; migration Job remains suspended.
- [blocked] Seed execution. Blocker: seed-capable image/runbook and data approval missing; seed Job remains suspended and intentionally blocked.
- [blocked] Smoke runtime. Blocker: no pods were started; `/api/health` was verified only via local container smoke before final image churn, not live cluster.

## Phase 7 - Product / Security / Compliance

- [x] Staging mocks documented. Evidence: ConfigMap keeps mock OAuth/payments/age/face/CSAM/media moderation flags enabled and visible.
- [blocked] Production readiness. Blocker: payments, KYC/age, face liveness, CSAM/media moderation, LLM provider, +18 legal/privacy/GDPR and escalation process remain unresolved.
- [x] Public exposure unchanged. Evidence: existing LAN/SSO IngressRoute only; no public route added.

## Specialist Checks

- [x] Research/PMO pass. Evidence: source, GitOps, cluster and image state revalidated locally.
- [x] DevOps/SRE verifier pass. Evidence: independent read-only pass identified `harbor-pull`, `latest`, digest pinning, env and migration gates.
- [x] Backend/build pass. Evidence: typecheck/test/build/Docker gates passed.
- [x] Security pass. Evidence: no secrets committed, no secret values read into files, no production exposure added.
- [blocked] Independent runtime QA. Blocker: staging runtime remains intentionally scaled to zero.
