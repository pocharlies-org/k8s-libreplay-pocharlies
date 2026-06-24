#!/usr/bin/env sh
# PROD-MEDIA-PURGE-ORPHAN-02 static contract validator.
#
# Asserts that the dormant media orphan *inventory* contract is well-formed,
# scoped, read-only, free of any physical-purge primitive, and NOT wired into
# any Argo-synced kustomization. It mutates nothing and prints no secret values.
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
contract_dir="$root/ops/libreplay-media-orphan"
external_secret="$contract_dir/externalsecret.yaml"
cronjob="$contract_dir/cronjob.yaml"
policy="$contract_dir/minio-orphan-policy.json"
sql="$contract_dir/postgres-orphan-role.sql"
readme="$contract_dir/README.md"
evidence_template="$contract_dir/activation-evidence-template.md"
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
require_file "$cronjob"
require_file "$policy"
require_file "$sql"
require_file "$readme"
require_file "$evidence_template"
require_file "$kustomization"
ok "activation evidence template and contract files are present for operator/PMO signoff"

# ---------------------------------------------------------------------------
# 1. ExternalSecret -- scoped, explicit remoteRefs, no dataFrom.
# ---------------------------------------------------------------------------
kubectl apply --dry-run=client -f "$external_secret" >/dev/null
ok "media orphan ExternalSecret contract is valid Kubernetes YAML"

require_pattern "$external_secret" '^kind:[[:space:]]*ExternalSecret[[:space:]]*$' \
  "orphan contract must be an ExternalSecret"
require_pattern "$external_secret" 'name:[[:space:]]*libreplay-media-orphan-secrets[[:space:]]*$' \
  "orphan ExternalSecret must be named libreplay-media-orphan-secrets"
require_pattern "$external_secret" 'namespace:[[:space:]]*libreplay[[:space:]]*$' \
  "orphan ExternalSecret must target namespace libreplay"
require_pattern "$external_secret" 'name:[[:space:]]*vault-backend[[:space:]]*$' \
  "orphan ExternalSecret must use ClusterSecretStore vault-backend"
require_pattern "$external_secret" 'kind:[[:space:]]*ClusterSecretStore[[:space:]]*$' \
  "orphan ExternalSecret must use ClusterSecretStore kind"
reject_pattern "$external_secret" 'dataFrom:' \
  "orphan ExternalSecret must not use dataFrom"

for key in MINIO_ORPHAN_ACCESS_KEY MINIO_ORPHAN_SECRET_KEY PG_ORPHAN_DSN; do
  require_pattern "$external_secret" "secretKey:[[:space:]]*${key}[[:space:]]*$" \
    "orphan ExternalSecret missing secretKey ${key}"
  require_pattern "$external_secret" "property:[[:space:]]*${key}[[:space:]]*$" \
    "orphan ExternalSecret missing remote property ${key}"
done

remote_count="$(grep -Ec 'key:[[:space:]]*secret/libreplay/media-orphan[[:space:]]*$' "$external_secret")"
[ "$remote_count" -eq 3 ] || fail "all orphan remoteRefs must use secret/libreplay/media-orphan; found ${remote_count}"
ok "orphan ExternalSecret uses explicit keys from secret/libreplay/media-orphan"

# ---------------------------------------------------------------------------
# 2. CronJob -- dormant, scoped secret, pinned worker digest, read-only, no
#    physical-purge primitive, no root credentials.
# ---------------------------------------------------------------------------
kubectl apply --dry-run=client -f "$cronjob" >/dev/null
ok "media orphan CronJob contract is valid Kubernetes YAML"

require_pattern "$cronjob" '^kind:[[:space:]]*CronJob[[:space:]]*$' \
  "orphan contract must include a CronJob"
require_pattern "$cronjob" 'name:[[:space:]]*libreplay-media-orphan-inventory[[:space:]]*$' \
  "orphan CronJob must be named libreplay-media-orphan-inventory"
require_pattern "$cronjob" 'namespace:[[:space:]]*libreplay[[:space:]]*$' \
  "orphan CronJob must target namespace libreplay"
require_pattern "$cronjob" '^[[:space:]]*suspend:[[:space:]]*true[[:space:]]*$' \
  "orphan CronJob must ship suspend: true (dormant / fail-closed)"

# Pinned worker image by immutable digest.
require_pattern "$cronjob" 'image:[[:space:]]*harbor\.e-dani\.com/homelab/libreplay-web:worker-sha-[0-9a-f]+@sha256:[0-9a-f]{64}[[:space:]]*$' \
  "orphan CronJob must pin the worker image by worker-sha tag and sha256 digest"

# Read-only inventory CLI invocation.
require_pattern "$cronjob" 'media:orphan-inventory' \
  "orphan CronJob must run the read-only media:orphan-inventory CLI"

# Must reference the scoped secret, never the application root secret.
require_pattern "$cronjob" 'name:[[:space:]]*libreplay-media-orphan-secrets[[:space:]]*' \
  "orphan CronJob must source credentials from libreplay-media-orphan-secrets"
reject_pattern "$cronjob" ': libreplay-secrets[[:space:]]' \
  "orphan CronJob must not reference the application root Secret libreplay-secrets"
reject_pattern "$cronjob" 'MINIO_ROOT' \
  "orphan CronJob must not reference MinIO root credentials"

# No physical-purge / delete / execute primitive anywhere in the CronJob (skip comments).
cronjob_code="$(grep -v '^[[:space:]]*#' "$cronjob" | grep -v '^[[:space:]]*$')"
if printf '%s\n' "$cronjob_code" | grep -Eq '(--execute|MEDIA_RETENTION_EXECUTE|deleteObject|DeleteObject|mc[[:space:]]+rb|mc[[:space:]]+rm|--remove|--force|--purge|s3:DeleteObject)'; then
  fail "orphan CronJob must not contain any physical-purge / delete / execute primitive"
fi
ok "orphan CronJob is dormant (suspend: true), digest-pinned, scoped and read-only"

# ---------------------------------------------------------------------------
# 3. Contract must stay OUTSIDE every Argo-synced kustomization.
# ---------------------------------------------------------------------------
reject_pattern "$kustomization" 'ops/libreplay-media-orphan|libreplay-media-orphan' \
  "orphan contract must remain outside the Argo-synced k8s/kustomization.yaml"
ok "orphan contract is not referenced by k8s/kustomization.yaml"

orphan_ref_hits="$(grep -RIl -- 'ops/libreplay-media-orphan\|libreplay-media-orphan' \
  "$root"/k8s "$root"/staging "$root"/production 2>/dev/null \
  | grep -E '/kustomization\.yaml$' || true)"
if [ -n "$orphan_ref_hits" ]; then
  fail "orphan contract is referenced by a synced kustomization: ${orphan_ref_hits}"
fi
ok "orphan contract is outside all k8s/staging/production kustomizations"

# ---------------------------------------------------------------------------
# 4. MinIO policy -- list-only on libreplay-media; no get/put/delete/admin/wildcard.
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  jq empty "$policy" >/dev/null
  ok "MinIO orphan policy is valid JSON"
fi
require_pattern "$policy" 'libreplay-media' "MinIO policy must reference source bucket libreplay-media"
require_pattern "$policy" 's3:ListBucket' "MinIO policy must allow ListBucket"
reject_pattern "$policy" 's3:GetObject|s3:PutObject|s3:DeleteObject|admin:|s3:\*' \
  "MinIO orphan policy must be list-only (no GetObject/PutObject/Delete/admin/wildcard)"
reject_pattern "$policy" 'libreplay-backups' \
  "MinIO orphan policy must not reference the backups bucket (no backup scope here)"
ok "MinIO orphan policy is list-only on libreplay-media"

# ---------------------------------------------------------------------------
# 5. Postgres role SQL -- read-only, variable-driven, no write/DDL/superuser.
# ---------------------------------------------------------------------------
require_pattern "$sql" 'libreplay_media_orphan' "SQL must define libreplay_media_orphan"
require_pattern "$sql" 'NOSUPERUSER' "SQL must force NOSUPERUSER"
require_pattern "$sql" 'NOCREATEDB' "SQL must force NOCREATEDB"
require_pattern "$sql" 'NOCREATEROLE' "SQL must force NOCREATEROLE"
require_pattern "$sql" 'GRANT SELECT ON ALL TABLES' "SQL must grant SELECT on current tables"
require_pattern "$sql" 'GRANT SELECT ON ALL SEQUENCES' "SQL must grant SELECT on current sequences"
require_pattern "$sql" 'ALTER DEFAULT PRIVILEGES' "SQL must grant default privileges for future objects"
require_pattern "$sql" "getenv[[:space:]]+pg_orphan_password[[:space:]]+PG_ORPHAN_PASSWORD" \
  "SQL must import pg_orphan_password from PG_ORPHAN_PASSWORD environment variable"
reject_pattern "$sql" "psql[[:space:]]+-v[[:space:]]*pg_orphan_password" \
  "SQL documentation must not suggest passing password via psql -v (argv/history risk)"
reject_pattern "$sql" "psql[[:space:]]+--variable([=[:space:]]|[[:space:]]+).*pg_orphan_password" \
  "SQL documentation must not suggest passing password via psql --variable (argv/history risk)"
reject_pattern "$sql" "PG_ORPHAN_PASSWORD[[:space:]]*=[^[:space:]]+[[:space:]]+psql" \
  "SQL documentation must not suggest inline PG_ORPHAN_PASSWORD assignment before psql (history risk)"
reject_pattern "$sql" 'GRANT[[:space:]]+(INSERT|UPDATE|DELETE|TRUNCATE|ALL)' \
  "SQL must not grant any write privilege to the orphan role"
reject_pattern "$sql" "PASSWORD[[:space:]]+'[^:]" \
  "SQL must not contain a literal password"
ok "Postgres orphan role SQL is read-only and environment-variable-driven"

# Reject documentation that suggests passing password via psql -v or argv.
reject_pattern "$readme" 'psql[[:space:]]+-v[[:space:]].*pg_orphan_password' \
  "README must not document passing password via psql -v (history/argv risk)"
reject_pattern "$readme" 'psql[[:space:]]+--variable([=[:space:]]|[[:space:]]+).*pg_orphan_password' \
  "README must not document passing password via psql --variable (history/argv risk)"
reject_pattern "$readme" "PG_ORPHAN_PASSWORD[[:space:]]*=[^[:space:]]+[[:space:]]+psql" \
  "README must not document inline PG_ORPHAN_PASSWORD assignment before psql (history risk)"
reject_pattern "$readme" "password[[:space:]]*as the psql variable" \
  "README must not suggest passing password as psql variable"
ok "README does not document insecure password-passing patterns"

reject_pattern "$evidence_template" 'psql[[:space:]]+-v[[:space:]].*pg_orphan_password' \
  "evidence template must not suggest passing password via psql -v"
reject_pattern "$evidence_template" 'psql[[:space:]]+--variable([=[:space:]]|[[:space:]]+).*pg_orphan_password' \
  "evidence template must not suggest passing password via psql --variable"
reject_pattern "$evidence_template" "PG_ORPHAN_PASSWORD[[:space:]]*=[^[:space:]]+[[:space:]]+psql" \
  "evidence template must not suggest inline PG_ORPHAN_PASSWORD assignment before psql"
ok "activation evidence template does not suggest password via argv"

# ---------------------------------------------------------------------------
# 6. No credential literals anywhere in the contract directory.
#    (Check for AWS keys and SSH keys only; template DSNs with placeholders OK)
# ---------------------------------------------------------------------------
if grep -RInE '(AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH |PRIVATE) KEY-----)' \
  "$contract_dir"; then
  fail "obvious credential literal found in orphan contract files"
fi
ok "no obvious credential literals found in orphan contract files"
