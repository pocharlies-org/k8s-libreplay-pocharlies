#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
external_secret="$root/ops/libreplay-backup/externalsecret.yaml"
policy="$root/ops/libreplay-backup/minio-backup-policy.json"
sql="$root/ops/libreplay-backup/postgres-backup-role.sql"
evidence_template="$root/ops/libreplay-backup/activation-evidence-template.md"
kustomization="$root/k8s/kustomization.yaml"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

require_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if ! grep -Eq "$pattern" "$file"; then
    fail "$description"
  fi
}

reject_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if grep -Eq "$pattern" "$file"; then
    fail "$description"
  fi
}

require_file "$external_secret"
require_file "$policy"
require_file "$sql"
require_file "$evidence_template"
require_file "$kustomization"

ok "activation evidence template is present for operator/PMO signoff"

kubectl apply --dry-run=client -f "$external_secret" >/dev/null
ok "backup ExternalSecret contract is valid Kubernetes YAML"

require_pattern "$external_secret" '^kind:[[:space:]]*ExternalSecret[[:space:]]*$' \
  "backup contract must be an ExternalSecret"
require_pattern "$external_secret" 'name:[[:space:]]*libreplay-backup-secrets[[:space:]]*$' \
  "backup ExternalSecret must be named libreplay-backup-secrets"
require_pattern "$external_secret" 'namespace:[[:space:]]*libreplay[[:space:]]*$' \
  "backup ExternalSecret must target namespace libreplay"
require_pattern "$external_secret" 'name:[[:space:]]*vault-backend[[:space:]]*$' \
  "backup ExternalSecret must use ClusterSecretStore vault-backend"
require_pattern "$external_secret" 'kind:[[:space:]]*ClusterSecretStore[[:space:]]*$' \
  "backup ExternalSecret must use ClusterSecretStore kind"
reject_pattern "$external_secret" 'dataFrom:' \
  "backup ExternalSecret must not use dataFrom"

for key in MINIO_BACKUP_ACCESS_KEY MINIO_BACKUP_SECRET_KEY PG_BACKUP_USER PG_BACKUP_PASSWORD; do
  require_pattern "$external_secret" "secretKey:[[:space:]]*${key}[[:space:]]*$" \
    "backup ExternalSecret missing secretKey ${key}"
  require_pattern "$external_secret" "property:[[:space:]]*${key}[[:space:]]*$" \
    "backup ExternalSecret missing remote property ${key}"
done

remote_count="$(grep -Ec 'key:[[:space:]]*secret/libreplay/backup[[:space:]]*$' "$external_secret")"
[ "$remote_count" -eq 4 ] || fail "all backup remoteRefs must use secret/libreplay/backup; found ${remote_count}"
ok "backup ExternalSecret uses explicit keys from secret/libreplay/backup"

reject_pattern "$kustomization" 'ops/libreplay-backup|libreplay-backup-secrets' \
  "backup contract must remain outside the Argo-synced kustomization"
ok "backup contract is not referenced by k8s/kustomization.yaml"

if command -v jq >/dev/null 2>&1; then
  jq empty "$policy" >/dev/null
  ok "MinIO backup policy is valid JSON"
fi
require_pattern "$policy" 'libreplay-media' "MinIO policy must reference source bucket libreplay-media"
require_pattern "$policy" 'libreplay-backups' "MinIO policy must reference backup bucket libreplay-backups"
reject_pattern "$policy" 's3:DeleteObject|admin:|s3:\*' \
  "MinIO policy must not include delete, admin or wildcard s3 permissions"
ok "MinIO policy avoids delete/admin/wildcard permissions"

require_pattern "$sql" 'libreplay_backup' "SQL must define libreplay_backup"
require_pattern "$sql" 'NOSUPERUSER' "SQL must force NOSUPERUSER"
require_pattern "$sql" 'NOCREATEDB' "SQL must force NOCREATEDB"
require_pattern "$sql" 'NOCREATEROLE' "SQL must force NOCREATEROLE"
require_pattern "$sql" 'GRANT SELECT ON ALL TABLES' "SQL must grant SELECT on current tables"
require_pattern "$sql" 'GRANT SELECT ON ALL SEQUENCES' "SQL must grant SELECT on current sequences"
require_pattern "$sql" 'ALTER DEFAULT PRIVILEGES' "SQL must grant default privileges for future objects"
require_pattern "$sql" ":\\{\\?pg_backup_password\\}" "SQL must require pg_backup_password psql variable"
reject_pattern "$sql" "PASSWORD[[:space:]]+'[^:]" \
  "SQL must not contain a literal password"
ok "Postgres backup role SQL is read-only and variable-driven"

if grep -RInE '(postgresql://[^[:space:]]+:[^[:space:]@]+@|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH |PRIVATE) KEY-----)' \
  "$root/ops/libreplay-backup"; then
  fail "obvious credential literal found in backup contract files"
fi
ok "no obvious credential literals found in backup contract files"
