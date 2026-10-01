# ARCHITECTURE.md — k8s-libreplay-pocharlies

> LibreReplay (plataforma de replays de partidas): manifiestos de web + Postgres + MinIO + Meilisearch (+ LiveKit,
> backups y contratos de producción/staging). Escrito por `architect` (SC-1426).

## 1. Clientes y versiones

| cliente | repositorio / ruta | versión desplegada | cómo se despliega |
|---|---|---|---|
| Web `libreplay-web` | `k8s/manifest.yaml` | imagen `harbor.e-dani.com/homelab/libreplay-web:profile-interview-faf51c26@sha256:878cb28a…`, `replicas: 2` en `origin/main` | ArgoCD app `libreplay` (path `k8s`, prune **false**) |
| Postgres propio (`postgres:16-alpine`), Meilisearch `v1.10`, MinIO `RELEASE.2024-09-13…`, Redis | `k8s/manifest.yaml` | tags | ídem |
| Staging | `staging/` (`kustomization.yaml` + `overlays/runtime/`) | contrato **contract-only**; runtime bloqueado hasta `scripts/check-libreplay-staging-preflight.sh --strict` | ArgoCD app `libreplay-staging` (path `staging`) |
| Producción real | `production/libreplay-production-contract.yaml` | **contract-only**, sin workloads; falla cerrado | sin Application |

El código de la aplicación vive en otro repo (imagen `libreplay-web`); aquí solo despliegue.

## 2. Dependencias, en ambos sentidos

- **Depende de** — Harbor, MinIO propio (no el compartido), Postgres propio (StatefulSet con PVC local, `reclaimPolicy: Delete`:
  borrar el PVC destruye datos), LiveKit (`livekit/`), VictoriaMetrics (`vmrule`, `vmprobe`, `vmservicescrape`, dashboard Grafana),
  Cloudflare (staging con `cloudflare-ipallowlist`), proveedores OAuth/SMTP de staging (secretos pendientes).
- **Dependen de él** — nadie del estate. Edge público en `k8s/public-edge.yaml`.
- **ArgoCD** (2 apps, mismo repo, tronco **`main`**, `origin/main` = f90b248): `libreplay` → `k8s`; `libreplay-staging` → `staging`.

## 3. Stack

| pieza | versión | para qué | no se usa en su lugar |
|---|---|---|---|
| Kustomize (+ overlays staging) | — | render | Helm |
| Postgres 16, Meilisearch 1.10, MinIO, mc | ver §1 | datos y búsqueda | servicios compartidos (Postgres/MinIO del estate) por decisión del proyecto |
| Bash `scripts/check-libreplay-*.sh` | — | contratos (alertas, backup, livekit, media, staging, synthetics) | — |

## 4. Componentes compartidos

| concepto | pieza canónica | ruta | quién la usa |
|---|---|---|---|
| Contratos de entorno | `staging/…contract.yaml`, `production/…contract.yaml` | ídem | CI y operación |
| Backup / orphan de media | `ops/libreplay-backup/`, `ops/libreplay-media-orphan/` (CronJob, roles SQL, políticas MinIO) | ídem | este proyecto |
| Auditorías y PMO | `docs/libreplay-*` | `docs/` | referencia |

## 5. Cómo se construye aquí

Todo cambio de producción pasa por los scripts de contrato (`check-libreplay-*-contract.sh`); está **prohibido `:latest`**
(el CI lo rechaza). Staging se arma por parches sobre la base (`overlays/runtime/patch-*.yaml`). Secretos solo vía ExternalSecret.

## 6. Tests y validaciones

```sh
for s in scripts/check-libreplay-*-contract.sh; do bash "$s"; done   # contratos
bash scripts/check-libreplay-staging-preflight.sh --strict           # desbloquea el runtime de staging
kustomize build k8s && kustomize build staging
```
No hay tests unitarios (solo comprobaciones de contrato). Cobertura **pendiente de medir**.

## 7. CI/CD y despliegue

- `ci.yml` (`arc-k8s`): `reusable-ci.yml@main` + rechazo de tags `latest`; `release.yml` (tags/dispatch): `reusable-manifest-release.yml`
  (artefacto `k8s-libreplay-pocharlies`); `pr-review.yml`.
- Despliegue: merge a `main` → ArgoCD (`prune: false`). **Validación en producción**: `kubectl -n libreplay get deploy`, web respondiendo
  en su host, probes de `vmprobe`. Synced ≠ funcionando. Pendiente de ejecutar.

## 8. Decisiones y trampas

- **Contradicción**: el README dice «2026-05-22: parado a `replicas: 0`» pero `origin/main` fija `libreplay-web` a 2 réplicas: verificar el
  estado vivo (`kubectl`) y corregir el README.
- README con «k3s v1.32.5» y enlace al repo gitops de la org vieja.
- PVC con `reclaimPolicy: Delete`: nunca borrar PVC sin backup (`ops/libreplay-backup`).
- Producción real **bloqueada** (auditoría PMO 2026-06-19): no promover `production/` hasta pasar los contratos.

Última verificación contra el código: 2026-10-01 · f90b248 (origin/main)
