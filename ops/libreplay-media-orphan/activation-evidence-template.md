# LibrePlay Media Orphan Inventory Activation Evidence -- PROD-MEDIA-PURGE-ORPHAN-02

Status: TEMPLATE. Copy this file, fill it in during the manual bootstrap, and
attach it to the PMO/Security signoff. **Never paste secret values** into a
filled copy -- record key names, role names, policy shapes, and `<redacted>`
placeholders only.

This template is the human evidence that complements the automated, read-only
checker `scripts/check-libreplay-media-orphan-activation.sh`. The checker proves
the ExternalSecret is Ready, the Secret carries the required key names, and no
orphan CronJob is un-suspended; this document proves the *upstream* MinIO/PG/Vault
bootstrap was scoped, least privilege, decoupled from production secrets, and
free of any physical-purge primitive -- none of which a key-name check can see.

---

## 0. Run metadata

- Operator: `<name>`
- Date (UTC): `<YYYY-MM-DDTHH:MMZ>`
- Cluster / context: `<context name>`
- Namespace: `libreplay`
- Vault path under bootstrap: `secret/libreplay/media-orphan`
- Worker image digest pinned in `cronjob.yaml`: `worker-sha-<...>@sha256:<...>`
- Ticket / change ref: `<PROD-MEDIA-PURGE-ORPHAN-02 ...>`

---

## 1. Automated checker output (read-only)

- [ ] `scripts/check-libreplay-media-orphan-contract.sh` -- PASS.
      Evidence (paste tail, no secrets):
      ```text
      <paste OK lines>
      ```
- [ ] `scripts/check-libreplay-media-orphan-activation.sh` (report mode) -- captured.
      Evidence:
      ```text
      <paste OK/BLOCKED lines -- values are never printed by the checker>
      ```
- [ ] `scripts/check-libreplay-media-orphan-activation.sh --strict` -- exits 0 only
      after the bootstrap is complete.
      Evidence:
      ```text
      <paste final verdict line>
      ```

---

## 2. MinIO scoped service account (list-only, policy redacted)

The inventory must authenticate with a scoped service account, never with the
MinIO root/admin alias.

- [ ] Service account minted from a one-time, audited operator session (root
      alias used interactively, never written into a manifest/CronJob/image).
      Evidence: `<command name only, e.g. "mc admin user svcacct add", timestamp>`
- [ ] Root/admin alias removed from the operator shell/config after bootstrap.
      Evidence: `<mc alias rm <alias> -- confirmation, no keys>`
- [ ] Attached policy matches `ops/libreplay-media-orphan/minio-orphan-policy.json`:
      `libreplay-media` = `ListBucket`/`GetBucketLocation` only; **no**
      `s3:GetObject`, **no** `s3:PutObject`, **no** `s3:DeleteObject`, **no**
      `admin:*`, **no** `s3:*` wildcard.
      Evidence (policy JSON with `Principal`/account redacted):
      ```json
      <paste `mc admin policy info` output, account id redacted>
      ```
- [ ] Service account access key recorded ONLY in Vault
      `secret/libreplay/media-orphan` as `MINIO_ORPHAN_ACCESS_KEY` /
      `MINIO_ORPHAN_SECRET_KEY`.
      Evidence: `<key NAME present; value redacted>`
- [ ] Root/admin key was NOT persisted to `secret/libreplay/media-orphan`.
      Evidence: `<confirm only the two minted key names exist for MinIO>`

---

## 3. Postgres `libreplay_media_orphan` read-only role

Apply `ops/libreplay-media-orphan/postgres-orphan-role.sql` against the LibrePlay
application database, passing the password via the environment variable
`PG_ORPHAN_PASSWORD` (never via command-line arguments, shell history, or `psql -v`
which would persist in history).

- [ ] Role created/altered as `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
      NOINHERIT NOREPLICATION`.
      Evidence (`\du libreplay_media_orphan`, attributes only):
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
- [ ] Read-only DSN `PG_ORPHAN_DSN` (role `libreplay_media_orphan`) written ONLY
      to Vault `secret/libreplay/media-orphan` -- built outside any committed file.
      Evidence: `<key NAME present; DSN/password redacted>`

---

## 4. Vault path populated and read-proven (values redacted)

- [ ] `secret/libreplay/media-orphan` populated with exactly the three
      properties: `MINIO_ORPHAN_ACCESS_KEY`, `MINIO_ORPHAN_SECRET_KEY`,
      `PG_ORPHAN_DSN`.
      Evidence (`vault kv get -format=json ... | jq '.data.data | keys'` --
      KEY NAMES ONLY):
      ```json
      ["MINIO_ORPHAN_ACCESS_KEY","MINIO_ORPHAN_SECRET_KEY","PG_ORPHAN_DSN"]
      ```
- [ ] ExternalSecret read proven: `ExternalSecret/libreplay-media-orphan-secrets`
      reports `Ready=True` and `Secret/libreplay-media-orphan-secrets`
      materialized with the three key names.
      Evidence: `<paste checker OK lines for ExternalSecret + Secret keys>`
- [ ] The ESO Vault read policy is scoped to `secret/libreplay/media-orphan` only.
      Evidence: `<policy name + path scope; no token/secret values>`

---

## 5. No admin/root credentials and no physical-purge primitive

- [ ] No MinIO root/admin alias or key exists in the inventory CronJob env,
      initContainer or image layer; the CronJob references only
      `Secret/libreplay-media-orphan-secrets`, never `Secret/libreplay-secrets`.
      Evidence: `<scan/observation summary>`
- [ ] No PG superuser/owner DSN is used as the inventory identity.
      Evidence: `<confirm only libreplay_media_orphan is referenced>`
- [ ] The CronJob carries no physical-purge / S3 delete primitive (`--execute`,
      `MEDIA_RETENTION_EXECUTE`, `deleteObject`, `mc rb`, `mc rm`, `--remove`,
      `--force`, `--purge`).
      Evidence: `scripts/check-libreplay-media-orphan-contract.sh` OK line for
      forbidden-token scan.
- [ ] A redacted dry-run of `media:orphan-inventory` produced sanitized counts
      only (`scanned/referenced/orphans.*`), no raw object keys.
      Evidence: `<paste sanitized counts; confirm no object-key strings>`
- [ ] No literal DSN/key/password/base64 secret in any committed file.
      Evidence: `git grep -nE 'AKIA|password|MINIO_ORPHAN_(ACCESS|SECRET)_KEY=|postgresql://[^ ]+:[^ @]+@' -- ops/libreplay-media-orphan` -- `<no literal values>`

---

## 6. No PROD-10A / production secret coupling

- [ ] No read of, or edit to, `secret/libreplay/production`, `secret/libreplay/backup`
      or any PROD-10A (real-auth/SMTP) Vault path or Secret during this bootstrap.
      Evidence: `<confirm distinct Vault path + distinct ExternalSecret>`
- [ ] `ExternalSecret/libreplay-media-orphan-secrets` uses explicit `remoteRef`
      keys from `secret/libreplay/media-orphan` only -- no `dataFrom`, no
      production path.
      Evidence: `<paste check-libreplay-media-orphan-contract.sh OK line>`
- [ ] No change to the production app ConfigMap/Secret/ExternalSecret as part of
      this work. Evidence: `git diff --stat` shows only `ops/libreplay-media-orphan/*`,
      `scripts/check-libreplay-media-orphan-*.sh` and docs.

---

## 7. PMO / Security signoff BEFORE the CronJob is un-suspended

The credential bootstrap above does NOT authorize a recurring job. Un-suspending
the CronJob and adding it to the Argo-synced path is a separate, later step.

- [ ] `scripts/check-libreplay-media-orphan-activation.sh --strict` exits 0.
- [ ] Sections 2-6 complete with redacted evidence attached.
- [ ] The inventory CronJob is still `suspend: true` and still outside every
      kustomization (checker confirms).
- [ ] Security signoff: `<name / date / decision>`
- [ ] PMO signoff: `<name / date / decision>`
- [ ] Only after both signoffs may the CronJob be un-suspended and added to the
      Argo-synced path. Physical purge of orphan candidates remains a separate,
      legally-gated task and is NOT authorized by this signoff.

---

## Redaction rules (read before filling this in)

- Record key NAMES, role NAMES, policy SHAPES, statuses -- never secret values.
- Use `<redacted>` for any value-shaped field.
- Do not paste `vault kv get` value output, `mc admin user svcacct info` keys,
  or any password/DSN. Keys-only (`jq 'keys'`) listings are acceptable.
- Do not paste raw S3 object keys from any inventory run; counts only.
- Do not enable shell tracing (`set -x`) while collecting evidence.
