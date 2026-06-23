# LibrePlay Backup Credential Contract

Status: contract-only. Nothing in this directory is referenced by
`k8s/kustomization.yaml` yet.

## Purpose

`PROD-DR-BACKUP-02` prepares scoped identities for logical backups without
putting root/admin credentials into recurring jobs.

## Secret Contract

Vault path:

```text
secret/libreplay/backup
```

Allowed properties only:

```text
MINIO_BACKUP_ACCESS_KEY
MINIO_BACKUP_SECRET_KEY
PG_BACKUP_USER
PG_BACKUP_PASSWORD
```

`externalsecret.yaml` materializes those keys as
`Secret/libreplay-backup-secrets` through `ClusterSecretStore/vault-backend`.
It uses explicit `remoteRef` entries and intentionally avoids `dataFrom`.

## Bootstrap Order

1. Security/PMO approve activation.
2. A human/operator mints a MinIO service account from an audited, one-time
   admin session and attaches `minio-backup-policy.json`.
3. The operator writes only the minted service-account keys to
   `secret/libreplay/backup`.
4. The operator runs `postgres-backup-role.sql` while connected to
   `libreplay_lan`, passing the password as the psql variable
   `pg_backup_password`.
5. The operator writes `PG_BACKUP_USER=libreplay_backup` and the generated
   password to `secret/libreplay/backup`.
6. PMO verifies the ExternalSecret, role grants and MinIO policy without
   printing secret values.
7. Only then may the ExternalSecret and later backup CronJobs be added to the
   Argo-synced path.

## Forbidden Actions

- Do not add this directory to `k8s/kustomization.yaml` until the Vault path is
  populated and Security/PMO approve activation.
- Do not use MinIO root/admin credentials in any recurring backup job.
- Do not use the application DB owner or superuser as the recurring PG backup
  credential.
- Do not use `ExternalSecret.dataFrom` for backup credentials.
- Do not pass DSNs, passwords or access keys as command arguments.
- Do not run `mc mirror --remove`.
- Do not restore into the live namespace, live database, live bucket or live
  Meili index.
- Do not introduce a recurring Meili dump in the minimal scope; rebuild/reindex
  from Postgres after restore.

## Activation Evidence Required

- `Secret/libreplay-backup-secrets` exists by name and expected key names only;
  values are not printed.
- MinIO policy inspection proves read/list on `libreplay-media`, write/list/read
  on `libreplay-backups`, and no delete/admin verbs.
- `\du libreplay_backup` and grants prove read-only, no superuser and no write
  privileges.
- Static validator passes:

```sh
scripts/check-libreplay-backup-contract.sh
```

- Non-destructive restore rehearsal passes in scratch targets before any backup
  path is called production-ready.

## Activation Gate (Phase C)

Two artifacts gate the manual bootstrap. Neither one mutates the cluster or
Vault, and neither prints secret values.

1. `scripts/check-libreplay-backup-activation.sh` — read-only live checker.
   - Defaults to **report** mode (exits 0 while the bootstrap is still pending);
     pass `--strict` to make any remaining blocker a non-zero exit.
   - Runs `scripts/check-libreplay-backup-contract.sh` first (static contract).
   - Reports the Argo app `libreplay` status if reachable (the backup contract
     must stay outside the synced `k8s` path).
   - Checks whether `ExternalSecret/libreplay-backup-secrets` and
     `Secret/libreplay-backup-secrets` exist in namespace `libreplay`, and lists
     only the REQUIRED key NAMES (`MINIO_BACKUP_ACCESS_KEY`,
     `MINIO_BACKUP_SECRET_KEY`, `PG_BACKUP_USER`, `PG_BACKUP_PASSWORD`).
   - Reports `BLOCKED` until the ExternalSecret is `Ready=True` and the Secret
     carries all required keys.
   - Confirms no backup CronJob exists yet (a credential-only gate), and reports
     any present CronJob explicitly as a hard failure.

   ```sh
   scripts/check-libreplay-backup-activation.sh          # report mode
   scripts/check-libreplay-backup-activation.sh --strict # gate before signoff
   ```

2. `activation-evidence-template.md` — operator evidence template. Copy it,
   fill it during the bootstrap with **redacted** values only, and attach it to
   PMO/Security signoff. It captures what a key-name check cannot see: the MinIO
   scoped service-account policy, the PG `libreplay_backup` read-only grants, the
   Vault path populated/read-proven, the absence of admin/root creds in the
   cluster, no PROD-10A coupling, and PMO/Security signoff before any CronJob or
   restore rehearsal is added.

The checker reaching strict-green is necessary but **not sufficient**: backup
CronJobs and any restore rehearsal stay blocked until the evidence template is
complete and both Security and PMO sign off.
