# k8s-libreplay-pocharlies

LibreReplay — plataforma de replays de partidas. Monorepo: web + postgres propio + minio + redis + meilisearch + mailpit

## Cluster
- **Master**: x86 ubuntu (192.168.50.142), k3s v1.32.5
- **Workers**: nvidia-dgx (dgx1 ARM64), gx10-ec3d (dgx2 ARM64), sauvage (WireGuard edge)

## GitOps
Gestionado por ArgoCD desde [k8s-gitops-pocharlies](https://github.com/pocharlies/k8s-gitops-pocharlies).

## Estado operativo
- 2026-05-22: LibreReplay queda parado a `replicas: 0` completo hasta migrar/sembrar datos.
- PVCs y Services se conservan para la futura migración de Postgres, Redis, MinIO y Meilisearch.
- 2026-06-19: LAN demo validado, pero producción sigue bloqueada. Auditoría PMO:
  [docs/libreplay-production-readiness-pmo.md](docs/libreplay-production-readiness-pmo.md).
  Runbook para desbloquear staging real de Google/Facebook/SMTP:
  [docs/libreplay-staging-auth-runbook.md](docs/libreplay-staging-auth-runbook.md).
  Contrato `staging` aplicado en modo contract-only; runtime bloqueado hasta
  que `scripts/check-libreplay-staging-preflight.sh --strict` pase:
  [staging/libreplay-staging-contract.yaml](staging/libreplay-staging-contract.yaml).
- 2026-06-20: Contrato `production` estático preparado en modo contract-only;
  no define workloads/ingress y falla cerrado con todos los mocks desactivados:
  [production/libreplay-production-contract.yaml](production/libreplay-production-contract.yaml).
