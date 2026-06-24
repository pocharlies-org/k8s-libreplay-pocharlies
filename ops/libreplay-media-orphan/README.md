# LibrePlay Media Orphan Inventory Credential Contract

Status: contract-only / DORMANT (read-only inventory contract prepared, no activation yet).
Nothing in this directory is referenced by `k8s/kustomization.yaml` (or any
staging/production kustomization) yet, and the CronJob ships `suspend: true`.

## Purpose

`PROD-MEDIA-PURGE-ORPHAN-02` prepares a recurring, **read-only** media orphan
*inventory* on scoped least-privilege identities, without ever putting the
application MinIO root credentials into a recurring job and **without any
physical purge / delete primitive**.

The inventory reconciles the MinIO `libreplay-media` object listing against the
DB-referenced media/variant keys and emits sanitized counts only (no raw object
keys). It is dry-run by design: the source CLI `@libreplay/jobs
media:orphan-inventory` has no `--execute` path and issues no S3 delete. Physical
deletion of orphan candidates is a separate, later, legally-gated step and is
explicitly out of scope here.

## Secret Contract

Vault path:

```text
secret/libreplay/media-orphan
```

Allowed properties only:

```text
MINIO_ORPHAN_ACCESS_KEY
MINIO_ORPHAN_SECRET_KEY
PG_ORPHAN_DSN
```

`externalsecret.yaml` materializes those keys as
`Secret/libreplay-media-orphan-secrets` through
`ClusterSecretStore/vault-backend`. It uses explicit `remoteRef` entries and
intentionally avoids `dataFrom`.

`cronjob.yaml` maps those scoped keys onto the worker's expected env names:

| Secret key                | Container env       | Identity                              |
| ------------------------- | ------------------- | ------------------------------------- |
| `MINIO_ORPHAN_ACCESS_KEY` | `MINIO_ACCESS_KEY`  | scoped MinIO service account (list)   |
| `MINIO_ORPHAN_SECRET_KEY` | `MINIO_SECRET_KEY`  | scoped MinIO service account (list)   |
| `PG_ORPHAN_DSN`           | `DATABASE_URL`      | read-only role `libreplay_media_orphan` |

Non-secret config (`MINIO_ENDPOINT`, `MINIO_BUCKET`, `MINIO_REGION`, ...) is read
from `ConfigMap/libreplay-config` via `envFrom`; the CronJob never references
`Secret/libreplay-secrets`.

## Bootstrap Order

1. Security/PMO approve activation.
2. A human/operator mints a MinIO service account from an audited, one-time
   admin session and attaches `minio-orphan-policy.json` (list-only on
   `libreplay-media`).
3. The operator writes only the minted service-account keys to
   `secret/libreplay/media-orphan` as `MINIO_ORPHAN_ACCESS_KEY` /
   `MINIO_ORPHAN_SECRET_KEY`.
4. The operator runs `postgres-orphan-role.sql` while connected to
   `libreplay_lan`, passing the password via the environment variable
   `PG_ORPHAN_PASSWORD` (never as a command-line argument or shell history).
5. The operator builds the read-only DSN
   `postgresql://libreplay_media_orphan:<password>@<host>:5432/libreplay_lan`
   outside any committed file and writes it to
   `secret/libreplay/media-orphan` as `PG_ORPHAN_DSN`.
6. PMO verifies the ExternalSecret, role grants and MinIO policy without
   printing secret values.
7. Only then may the ExternalSecret and the `suspend: true` CronJob be added to
   the Argo-synced path and un-suspended.

## Forbidden Actions

- Do not add this directory to any kustomization until the Vault path is
  populated and Security/PMO approve activation.
- Do not un-suspend `cronjob.yaml` (`suspend: true`) before activation signoff.
- Do not use MinIO root/admin credentials (`Secret/libreplay-secrets`
  `MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY`) in the inventory job.
- Do not use the application DB owner or superuser as the inventory credential.
- Do not grant the MinIO service account `s3:GetObject`, `s3:PutObject`,
  `s3:DeleteObject`, any `admin:*` verb or an `s3:*` wildcard -- list-only.
- Do not grant the Postgres role any write/DDL/ownership/superuser privilege.
- Do not use `ExternalSecret.dataFrom`.
- Do not pass the DSN, password or access keys as command arguments. Postgres role password must be provided via the `PG_ORPHAN_PASSWORD` environment variable only, never via `psql -v`, `psql --variable`, or any command-line argument that would persist in shell history.
- Do not add any physical-purge / S3 delete primitive (`--execute`,
  `MEDIA_RETENTION_EXECUTE`, `deleteObject`, `mc rb`, `mc rm`, `--remove`,
  `--force`, `--purge`) to this CronJob; the inventory is read-only.
- Do not introduce a backup CronJob, snapshot, restore or any other mutation in
  this scope.

## Activation Evidence Required

- `Secret/libreplay-media-orphan-secrets` exists by name and expected key names
  only; values are not printed.
- MinIO policy inspection proves list-only on `libreplay-media`, and **no**
  GetObject/PutObject/Delete/admin/wildcard verbs.
- `\du libreplay_media_orphan` and grants prove read-only, no superuser and no
  write privileges.
- Static validator passes:

```sh
scripts/check-libreplay-media-orphan-contract.sh
```

- A redacted dry-run of the inventory shows sanitized counts only (no raw object
  keys) before the CronJob is treated as production-ready.

## Activation Gate

Two artifacts gate the manual bootstrap. Neither one mutates the cluster or
Vault, and neither prints secret values.

1. `scripts/check-libreplay-media-orphan-activation.sh` -- read-only live checker.
   - Defaults to **report** mode (exits 0 while the bootstrap is still pending);
     pass `--strict` to make any remaining blocker a non-zero exit.
   - Runs `scripts/check-libreplay-media-orphan-contract.sh` first (static
     contract).
   - Reports the Argo app `libreplay` status if reachable (the orphan contract
     must stay outside the synced `k8s` path).
   - Checks whether `ExternalSecret/libreplay-media-orphan-secrets` and
     `Secret/libreplay-media-orphan-secrets` exist in namespace `libreplay`, and
     lists only the REQUIRED key NAMES (`MINIO_ORPHAN_ACCESS_KEY`,
     `MINIO_ORPHAN_SECRET_KEY`, `PG_ORPHAN_DSN`).
   - Reports `BLOCKED` until the ExternalSecret is `Ready=True` and the Secret
     carries all required keys.
   - Treats any **un-suspended** `libreplay-media-orphan-inventory` CronJob (or
     any other orphan CronJob) before signoff as a hard failure.

   ```sh
   scripts/check-libreplay-media-orphan-activation.sh          # report mode
   scripts/check-libreplay-media-orphan-activation.sh --strict # gate before signoff
   ```

2. `activation-evidence-template.md` -- operator evidence template. Copy it,
   fill it during the bootstrap with **redacted** values only, and attach it to
   PMO/Security signoff. It captures what a key-name check cannot see: the MinIO
   scoped list-only policy, the PG `libreplay_media_orphan` read-only grants, the
   Vault path populated/read-proven, the absence of admin/root creds and of any
   physical-purge primitive, no PROD-10A coupling, and PMO/Security signoff
   before the CronJob is un-suspended or added to the Argo-synced path.

The checker reaching strict-green is necessary but **not sufficient**: the
inventory CronJob stays suspended and outside the Argo-synced path until the
evidence template is complete and both Security and PMO sign off. Physical purge
of orphan candidates remains a separate, legally-gated task and is never enabled
by this contract.
