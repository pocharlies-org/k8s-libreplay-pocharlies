# LibrePlay PMO Master Checklist

Status: `LAN-ROLLOUT-IN-PROGRESS`
Last updated: 2026-06-19
Target: `https://libreplay.lan.e-dani.com`

## Directives

- [x] No exposicion publica; solo LAN/SSO existente. Evidence: `k8s/manifest.yaml` keeps only `IngressRoute/libreplay-lan`.
- [x] No importar ni borrar datos antiguos. Evidence: rollout uses database `libreplay_lan`; no PVC deletion or data import is encoded.
- [x] Sin passwords para usuarios/QA. Evidence: source commit `986ceec2b562...` uses `/api/auth/demo-login`; Playwright no longer references `SEED_AI_USER_PASSWORD` or `E2E_TEST_PASSWORD`.
- [x] Secrets internos siguen en secrets. Evidence: manifest reads `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, MinIO, Meili and `SEED_USER_PASSWORD` from `libreplay-secrets`.
- [x] Mocks visibles como LAN/no-prod. Evidence: ConfigMap enables mock flags; UI has demo/no-prod panel and creator/payment mock copy.
- [blocked] No cerrar con pods caidos, 404s, buttons mudos, skips criticos or missing secrets. Blocker: rollout and Playwright LAN are still pending.

## Acceptance Criteria

- [ ] Argo `libreplay` `Synced/Healthy`. Evidence required: `kubectl -n argocd get application libreplay`.
- [ ] Pods ready: Postgres, Redis, MinIO, Meili, web. Evidence required: `kubectl -n libreplay get pod,endpointslice -o wide`.
- [ ] `/api/health` and `/api/health/deps` return 200. Evidence required: LAN `curl`.
- [ ] Demo login works for member, moderator, admin, creator, club owner and newbie without typing passwords. Evidence required: API/UI smoke plus Playwright projects.
- [ ] Feed, discover, friends, messages, profiles, groups, clubs, dates, events, forum, blog, map, creator, admin, verification mock and payments mock work. Evidence required: full Playwright LAN report.
- [ ] Playwright LAN full suite passes with trace/screenshot/video and zero critical skips. Evidence required: JSON stats unexpected=0, flaky=0, skipped=0.
- [ ] Checklist final updated with commands, outputs and resolved blockers. Evidence required: this file updated at closeout.

## Source / Build

- [x] LAN demo source committed. Evidence: `/home/dibanez/k8s/libreplay` commits through `a129bb5 fix: mock LAN oracle and playwright artifacts` pushed to `origin/main`.
- [x] `pnpm typecheck`. Evidence: exited 0 on 2026-06-19.
- [x] `pnpm test`. Evidence: exited 0; config 4 tests, security 7 tests, auth no-tests pass, web 5 tests.
- [x] `pnpm lint`. Evidence: exited 0; one pre-existing Next font warning only.
- [x] `pnpm --filter @libreplay/web build`. Evidence: exited 0 and generated routes including `/api/auth/demo-login`, `/api/health/deps`, `/api/media/upload/[id]`.
- [x] Docker runner/tools/seed smoke builds. Evidence: local `docker build --target runner|tools|seed` exited 0.

## Images / Harbor

- [x] Web image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:sha-a129bb501edf@sha256:850d56ee775e2b7a6bd3f6228938b0639ebb355384db241af532436ad25496ba`.
- [x] Migrate tools image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:tools-sha-6b7f75034835@sha256:111b84a84c0b569cdd979bb890fc95c710e28954cfc5f90e83417febe9723e3e`.
- [x] Seed image pushed and inspected. Evidence: `harbor.e-dani.com/homelab/libreplay-web:seed-sha-15da141534f1@sha256:d1c44a5a95ae5330f8f1ce42b25412f88d702b65bee3dc58ce872e67142bfa77`.
- [x] Image labels match source. Evidence: web returned revision `a129bb501edf1a08433462de31f8450fe7ffd186`; tools returned `6b7f75034835e46f5bc0100b491e6e02ed591922`; seed returned `15da141534f1d75c4d638940113875b02e2aba00`.

## GitOps

- [x] Work is on Argo target branch. Evidence: repo branch `deploy/prod`, Argo target revision previously verified as `deploy/prod`.
- [x] Web image pinned by digest; no `latest`. Evidence: `k8s/manifest.yaml`.
- [x] Datastores scale to one replica. Evidence: StatefulSet/Deployments for Postgres, Redis, Meili and MinIO use `replicas: 1`.
- [x] DB fresh target is `libreplay_lan`. Evidence: Postgres `POSTGRES_DB=libreplay_lan`; `libreplay-db-init` creates DB if existing PVC lacks it.
- [x] MinIO bucket init is explicit. Evidence: `Job/libreplay-minio-init`.
- [x] Migrate and seed are real Jobs. Evidence: `Job/libreplay-db-migrate-6b7f750` and `Job/libreplay-db-seed-15da141`.
- [x] Job memory limits present. Evidence: all Jobs set memory requests/limits.
- [x] Server-side manifest dry-run passes. Evidence: `kubectl apply --server-side --force-conflicts --dry-run=server -f k8s/manifest.yaml` exited 0.
- [blocked] Live Argo sync pending. Blocker: GitOps commit/push and runtime secrets still pending at this checklist revision.

## Runtime Secrets

- [ ] `harbor-pull` exists in namespace `libreplay`. Evidence required: `kubectl -n libreplay get secret harbor-pull`.
- [ ] Vault/ExternalSecret exposes required app keys. Evidence required: key names only from `kubectl -n libreplay get secret libreplay-secrets`.
- [ ] Generated internal secrets are not printed or committed. Evidence required: command history/log review; no secret values in git.

Required keys: `DATABASE_URL`, `REDIS_URL`, `AUTH_SECRET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`, `MEILISEARCH_API_KEY`, `DB_USER`, `DB_PASSWORD`, `SEED_USER_PASSWORD`.

## Specialist Checks

- [x] Research/PMO pass. Evidence: memory source `rollout-2026-06-18T18-26-33...` used as clue and revalidated with repo/cluster commands.
- [x] DevOps read-only pass. Evidence: subagent reported blockers: missing `harbor-pull`, incomplete secret contract, job policy failures, no endpoints.
- [x] QA/Security read-only pass. Evidence: subagent reported blockers: local source not deployed, demo session risk, missing Playwright demo coverage.
- [x] Backend/frontend implementation pass. Evidence: demo login, health deps, upload proxy, seed and Playwright role projects implemented in commit `986ceec`.
- [ ] Runtime verification pass. Evidence required: Argo, pods, health, smoke and Playwright LAN outputs.
