# LibrePlay Backup Activation Evidence — PROD-DR-BACKUP-02

Status: TEMPLATE. Copy this file, fill it in during the manual bootstrap, and
attach it to the PMO/Security signoff. **Never paste secret values** into a
filled copy — record key names, role names, policy shapes, and `<redacted>`
placeholders only.

This template is the human evidence that complements the automated, read-only
checker `scripts/check-libreplay-backup-activation.sh`. The checker proves the
ExternalSecret is Ready and the Secret carries the required key names; this
document proves the *upstream* MinIO/PG/Vault bootstrap was scoped, least
privilege, and decoupled from production secrets — none of which a key-name
check can see.

---

## 0. Run metadata

- Operator: `<name>`
- Date (UTC): `<YYYY-MM-DDTHH:MMZ>`
- Cluster / context: `<context name>`
- Namespace: `libreplay`
- Vault path under bootstrap: `secret/libreplay/backup`
- Ticket / change ref: `<PROD-DR-BACKUP-02 ...>`

---

## 1. Automated checker output (read-only)

- [ ] `scripts/check-libreplay-backup-contract.sh` — PASS.
      Evidence (paste tail, no secrets):
      ```text
      <paste OK lines>
      ```
- [ ] `scripts/check-libreplay-backup-activation.sh` (report mode) — captured.
      Evidence:
      ```text
      <paste OK/BLOCKED lines — values are never printed by the checker>
      ```
- [ ] `scripts/check-libreplay-backup-activation.sh --strict` — exits 0 only
      after the bootstrap is complete.
      Evidence:
      ```text
      <paste final verdict line>
      ```

---

## 2. MinIO scoped service account (policy redacted)

The recurring jobs must authenticate with a scoped service account, never with
the MinIO root/admin alias.

- [ ] Service account minted from a one-time, audited operator session (root
      alias used interactively, never written into a manifest/CronJob/image).
      Evidence: `<command name only, e.g. "mc admin user svcacct add", timestamp>`
- [ ] Root/admin alias removed from the operator shell/config after bootstrap.
      Evidence: `<mc alias rm <alias> — confirmation, no keys>`
- [ ] Attached policy matches `ops/libreplay-backup/minio-backup-policy.json`:
      source bucket `libreplay-media` = `GetObject`/`ListBucket`/`GetBucketLocation`
      only; destination `libreplay-backups/{libreplay-media,postgres}/*` =
      `GetObject`/`PutObject` + bucket list; **no** `s3:DeleteObject`, **no**
      `admin:*`, **no** `s3:*` wildcard.
      Evidence (policy JSON with `Principal`/account redacted):
      ```json
      <paste `mc admin policy info` output, account id redacted>
      ```
- [ ] Service account access key recorded ONLY in Vault `secret/libreplay/backup`
      as `MINIO_BACKUP_ACCESS_KEY` / `MINIO_BACKUP_SECRET_KEY`.
      Evidence: `<key NAME present; value redacted>`
- [ ] Root/admin key was NOT persisted to `secret/libreplay/backup`.
      Evidence: `<confirm only the two minted key names exist for MinIO>`

---

## 3. Postgres `libreplay_backup` read-only role

Apply `ops/libreplay-backup/postgres-backup-role.sql` against the LibrePlay
application database, passing the password as the psql variable
`pg_backup_password` (never inline / never via argv).

- [ ] Role created/altered as `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
      NOINHERIT NOREPLICATION`.
      Evidence (`\du libreplay_backup`, attributes only):
      ```text
      <paste \du row>
      ```
- [ ] Grants prove read-only: `CONNECT` on DB, `USAGE` on schema `public`,
      `SELECT` on all tables and sequences, plus `ALTER DEFAULT PRIVILEGES`
      `SELECT` for future objects.
      Evidence (grant listing):
      ```text
      <paste grant rows>
      ```
- [ ] Negative proof: role has **no** `INSERT/UPDATE/DELETE/TRUNCATE`, **no**
      DDL, **no** ownership, **no** superuser/replication.
      Evidence: `<query/observation showing absence of write privileges>`
- [ ] `PG_BACKUP_USER=libreplay_backup` and `PG_BACKUP_PASSWORD` written ONLY to
      Vault `secret/libreplay/backup`.
      Evidence: `<key NAMES present; password redacted>`

---

## 4. Vault path populated and read-proven (values redacted)

- [ ] `secret/libreplay/backup` populated with exactly the four properties:
      `MINIO_BACKUP_ACCESS_KEY`, `MINIO_BACKUP_SECRET_KEY`, `PG_BACKUP_USER`,
      `PG_BACKUP_PASSWORD`.
      Evidence (`vault kv get -format=json ... | jq '.data.data | keys'` —
      KEY NAMES ONLY):
      ```json
      ["MINIO_BACKUP_ACCESS_KEY","MINIO_BACKUP_SECRET_KEY","PG_BACKUP_PASSWORD","PG_BACKUP_USER"]
      ```
- [ ] ExternalSecret read proven: `ExternalSecret/libreplay-backup-secrets`
      reports `Ready=True` and `Secret/libreplay-backup-secrets` materialized
      with the four key names.
      Evidence: `<paste checker OK lines for ExternalSecret + Secret keys>`
- [ ] The ESO Vault read policy is scoped to `secret/libreplay/backup` only.
      Evidence: `<policy name + path scope; no token/secret values>`

---

## 5. No admin/root credentials in the cluster

- [ ] No MinIO root/admin alias or key exists in any namespace `libreplay`
      Secret, ConfigMap, CronJob env, initContainer or image layer.
      Evidence: `<scan/observation summary>`
- [ ] No PG superuser/owner DSN is used as the recurring backup identity.
      Evidence: `<confirm only libreplay_backup is referenced>`
- [ ] No literal DSN/key/password/base64 secret in any committed GitOps file.
      Evidence: `git grep -nE 'AKIA|password|MINIO_|PG_BACKUP_PASSWORD=|postgresql://[^ ]+:[^ @]+@' -- ops/libreplay-backup` → `<no literal values>`

---

## 6. No PROD-10A coupling

- [ ] No read of, or edit to, `secret/libreplay/production` or any PROD-10A
      (real-auth/SMTP) Vault path or Secret during this bootstrap.
      Evidence: `<confirm distinct Vault path + distinct ExternalSecret>`
- [ ] `ExternalSecret/libreplay-backup-secrets` uses explicit `remoteRef` keys
      from `secret/libreplay/backup` only — no `dataFrom`, no production path.
      Evidence: `<paste check-libreplay-backup-contract.sh OK line>`
- [ ] No change to the production app ConfigMap/Secret/ExternalSecret as part of
      this work. Evidence: `git diff --stat` shows only `ops/libreplay-backup/*`
      and `scripts/check-libreplay-backup-*.sh`.

---

## 7. PMO / Security signoff BEFORE any CronJob or rehearsal

The credential bootstrap above does NOT authorize recurring jobs. Backup
CronJobs and any restore rehearsal are a separate, later step.

- [ ] `scripts/check-libreplay-backup-activation.sh --strict` exits 0.
- [ ] Sections 2–6 complete with redacted evidence attached.
- [ ] No backup CronJob exists yet (checker confirms; gate is credential-only).
- [ ] Security signoff: `<name / date / decision>`
- [ ] PMO signoff: `<name / date / decision>`
- [ ] Only after both signoffs may backup CronJobs and a scratch-only restore
      rehearsal be designed and added to the Argo-synced path.

---

## Redaction rules (read before filling this in)

- Record key NAMES, role NAMES, policy SHAPES, statuses — never secret values.
- Use `<redacted>` for any value-shaped field.
- Do not paste `vault kv get` value output, `mc admin user svcacct info` keys,
  or any password/DSN. Keys-only (`jq 'keys'`) listings are acceptable.
- Do not enable shell tracing (`set -x`) while collecting evidence.
