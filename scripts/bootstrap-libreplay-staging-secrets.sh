#!/usr/bin/env bash
set -euo pipefail
umask 077

mode="dry-run"
sync_eso=0
vault_path="${VAULT_PATH:-secret/libreplay/staging}"
namespace="${NAMESPACE:-libreplay-staging}"

usage() {
  cat <<'EOF'
Usage:
  scripts/bootstrap-libreplay-staging-secrets.sh [--dry-run]
  scripts/bootstrap-libreplay-staging-secrets.sh --write [--sync-eso]

Creates the Vault KV v2 payload required by ExternalSecret/libreplay-secrets in
libreplay-staging without printing secret values.

Required provider environment variables:
  GOOGLE_CLIENT_ID
  GOOGLE_CLIENT_SECRET
  FACEBOOK_CLIENT_ID
  FACEBOOK_CLIENT_SECRET
  SMTP_HOST
  SMTP_PORT
  SMTP_USER
  SMTP_PASSWORD

Generated when absent:
  DATABASE_URL
  REDIS_URL
  AUTH_SECRET
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  MEILISEARCH_API_KEY
  DB_USER
  DB_PASSWORD
  SEED_USER_PASSWORD
  OAUTH_TOKEN_ENC_KEY
  METRICS_BEARER_TOKEN

Write mode also requires these explicit evidence acknowledgements:
  LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
  LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1

The acknowledgements mean the Google and Meta apps are authorized for:
  https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
  https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
and the SMTP sender/domain can send as LibrePlay <noreply@libreplay.e-dani.com>.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) mode="dry-run" ;;
    --write) mode="write" ;;
    --sync-eso) sync_eso=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'FAIL: unknown argument: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$-" == *x* ]]; then
  printf 'FAIL: refusing to run with shell tracing enabled; it could leak secrets\n' >&2
  exit 2
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'FAIL: missing required command: %s\n' "$1" >&2
    exit 127
  }
}

random_hex() {
  openssl rand -hex "$1"
}

random_b64url() {
  openssl rand -base64 "$1" | tr '+/' '-_' | tr -d '=\n'
}

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

block() {
  printf 'BLOCKED: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

need openssl
need python3

provider_keys=(
  GOOGLE_CLIENT_ID
  GOOGLE_CLIENT_SECRET
  FACEBOOK_CLIENT_ID
  FACEBOOK_CLIENT_SECRET
  SMTP_HOST
  SMTP_PORT
  SMTP_USER
  SMTP_PASSWORD
)

missing=()
for key in "${provider_keys[@]}"; do
  if [ -z "${!key:-}" ]; then
    missing+=("$key")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  printf 'BLOCKED: missing required provider variables: %s\n' "${missing[*]}" >&2
  printf 'INFO: no Vault write attempted; provider console/SMTP evidence is still required\n' >&2
  exit 1
fi

case "${GOOGLE_CLIENT_ID}" in
  *.apps.googleusercontent.com) ;;
  *) fail "GOOGLE_CLIENT_ID must look like a Google OAuth web client id" ;;
esac

if ! [[ "${FACEBOOK_CLIENT_ID}" =~ ^[0-9]+$ ]]; then
  fail "FACEBOOK_CLIENT_ID must look like a numeric Meta app id"
fi

if ! [[ "${SMTP_PORT}" =~ ^[0-9]+$ ]]; then
  fail "SMTP_PORT must be an integer"
fi

for key in "${provider_keys[@]}"; do
  value="${!key}"
  if [[ "$value" =~ (TODO|todo|PLACEHOLDER|placeholder|CHANGEME|changeme) ]]; then
    fail "${key} looks like a placeholder"
  fi
done

DB_USER="${DB_USER:-libreplay_staging}"
DB_PASSWORD="${DB_PASSWORD:-$(random_hex 24)}"
db_user_enc="$(urlencode "$DB_USER")"
db_password_enc="$(urlencode "$DB_PASSWORD")"
DATABASE_URL="${DATABASE_URL:-postgresql://${db_user_enc}:${db_password_enc}@libreplay-postgres.libreplay-staging.svc.cluster.local:5432/libreplay_staging?schema=public}"
REDIS_URL="${REDIS_URL:-redis://libreplay-redis.libreplay-staging.svc.cluster.local:6379}"
AUTH_SECRET="${AUTH_SECRET:-$(random_hex 32)}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-libreplay-staging-$(random_hex 8)}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-$(random_hex 32)}"
MEILISEARCH_API_KEY="${MEILISEARCH_API_KEY:-$(random_hex 32)}"
SEED_USER_PASSWORD="${SEED_USER_PASSWORD:-$(random_b64url 24)}"
OAUTH_TOKEN_ENC_KEY="${OAUTH_TOKEN_ENC_KEY:-$(random_hex 32)}"
METRICS_BEARER_TOKEN="${METRICS_BEARER_TOKEN:-$(random_hex 32)}"

[[ "$DATABASE_URL" == *"libreplay-postgres.libreplay-staging.svc.cluster.local:5432"* ]] \
  || fail "DATABASE_URL must target the staging Postgres service"
[[ "$DATABASE_URL" == *"libreplay_staging"* ]] \
  || fail "DATABASE_URL must target the libreplay_staging database"
[[ "$REDIS_URL" == "redis://libreplay-redis.libreplay-staging.svc.cluster.local:6379"* ]] \
  || fail "REDIS_URL must target the staging Redis service"
[[ "${#AUTH_SECRET}" -ge 32 ]] || fail "AUTH_SECRET must be at least 32 characters"
[[ "${#MINIO_ACCESS_KEY}" -ge 3 ]] || fail "MINIO_ACCESS_KEY must be at least 3 characters"
[[ "${#MINIO_SECRET_KEY}" -ge 16 ]] || fail "MINIO_SECRET_KEY must be at least 16 characters"
[[ "${#MEILISEARCH_API_KEY}" -ge 16 ]] || fail "MEILISEARCH_API_KEY must be at least 16 characters"
[[ "${#DB_USER}" -ge 3 ]] || fail "DB_USER must be at least 3 characters"
[[ "${#DB_PASSWORD}" -ge 16 ]] || fail "DB_PASSWORD must be at least 16 characters"
[[ "${#SEED_USER_PASSWORD}" -ge 16 ]] || fail "SEED_USER_PASSWORD must be at least 16 characters"
[[ "$OAUTH_TOKEN_ENC_KEY" =~ ^[0-9a-fA-F]{64}$ ]] \
  || fail "OAUTH_TOKEN_ENC_KEY must be exactly 64 hex characters"
[[ "${#METRICS_BEARER_TOKEN}" -ge 32 ]] || fail "METRICS_BEARER_TOKEN must be at least 32 characters"

payload_keys=(
  DATABASE_URL
  REDIS_URL
  AUTH_SECRET
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  MEILISEARCH_API_KEY
  DB_USER
  DB_PASSWORD
  SEED_USER_PASSWORD
  GOOGLE_CLIENT_ID
  GOOGLE_CLIENT_SECRET
  FACEBOOK_CLIENT_ID
  FACEBOOK_CLIENT_SECRET
  OAUTH_TOKEN_ENC_KEY
  SMTP_HOST
  SMTP_PORT
  SMTP_USER
  SMTP_PASSWORD
  METRICS_BEARER_TOKEN
)

for key in "${payload_keys[@]}"; do
  export "$key"
done

ok "validated ${#payload_keys[@]} staging secret keys locally; values were not printed"

if [ "$mode" = "dry-run" ]; then
  ok "dry-run complete; no Vault write attempted"
  if [ "${LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED:-0}" != "1" ]; then
    printf 'BLOCKED: write mode still needs LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1\n' >&2
  fi
  if [ "${LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED:-0}" != "1" ]; then
    printf 'BLOCKED: write mode still needs LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1\n' >&2
  fi
  exit 0
fi

if [ "${LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED:-0}" != "1" ]; then
  block "refusing Vault write until LibrePlay staging Google/Meta callback evidence is confirmed"
fi
if [ "${LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED:-0}" != "1" ]; then
  block "refusing Vault write until LibrePlay staging SMTP sender/domain evidence is confirmed"
fi

need vault
vault status >/dev/null

payload_file="$(mktemp)"
trap 'rm -f "$payload_file"' EXIT

python3 - "$payload_file" <<'PY'
import json
import os
import sys

keys = [
    "DATABASE_URL",
    "REDIS_URL",
    "AUTH_SECRET",
    "MINIO_ACCESS_KEY",
    "MINIO_SECRET_KEY",
    "MEILISEARCH_API_KEY",
    "DB_USER",
    "DB_PASSWORD",
    "SEED_USER_PASSWORD",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "FACEBOOK_CLIENT_ID",
    "FACEBOOK_CLIENT_SECRET",
    "OAUTH_TOKEN_ENC_KEY",
    "SMTP_HOST",
    "SMTP_PORT",
    "SMTP_USER",
    "SMTP_PASSWORD",
    "METRICS_BEARER_TOKEN",
]

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump({key: os.environ[key] for key in keys}, fh, separators=(",", ":"))
    fh.write("\n")
PY

vault kv put "$vault_path" "@${payload_file}" >/dev/null
ok "wrote ${#payload_keys[@]} key names to Vault path ${vault_path}; values were not printed"

if [ "$sync_eso" -eq 1 ]; then
  need kubectl
  kubectl -n "$namespace" annotate externalsecret libreplay-secrets \
    "force-sync=$(date +%s)" --overwrite >/dev/null
  ok "requested ExternalSecret refresh for ${namespace}/libreplay-secrets"
fi

ok "next gate: scripts/check-libreplay-staging-preflight.sh --strict"
