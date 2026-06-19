#!/usr/bin/env sh
set -eu

namespace="${1:-${NAMESPACE:-libreplay-staging}}"
secret_name="${SECRET_NAME:-libreplay-secrets}"
config_name="${CONFIG_NAME:-libreplay-config}"

required_secret_keys="
DATABASE_URL
REDIS_URL
AUTH_SECRET
MINIO_ACCESS_KEY
MINIO_SECRET_KEY
MEILISEARCH_API_KEY
DB_USER
DB_PASSWORD
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
FACEBOOK_CLIENT_ID
FACEBOOK_CLIENT_SECRET
OAUTH_TOKEN_ENC_KEY
SMTP_HOST
SMTP_PORT
SMTP_USER
SMTP_PASSWORD
"

required_config_values="
NODE_ENV=production
DEPLOYMENT_MODE=staging
USE_MOCK_OAUTH=false
PAYMENT_PROVIDER=disabled
ENABLE_MOCK_PAYMENTS=false
AUTH_EMAIL_PROVIDER=smtp
ENABLE_LAN_DEMO_LOGIN=false
"

tmp_keys="$(mktemp)"
trap 'rm -f "$tmp_keys"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'OK: %s\n' "$*"
}

kubectl -n "$namespace" get secret "$secret_name" \
  -o go-template='{{range $k, $v := .data}}{{printf "%s\n" $k}}{{end}}' \
  | sort > "$tmp_keys"

for key in $required_secret_keys; do
  if ! grep -Fx "$key" "$tmp_keys" >/dev/null; then
    fail "missing secret key ${secret_name}/${key} in namespace ${namespace}"
  fi
done
info "required secret key names exist in ${namespace}/${secret_name}; values were not printed"

for pair in $required_config_values; do
  key="${pair%%=*}"
  expected="${pair#*=}"
  actual="$(kubectl -n "$namespace" get configmap "$config_name" -o "jsonpath={.data.${key}}")"
  if [ "$actual" != "$expected" ]; then
    fail "config ${config_name}/${key} expected ${expected}, got ${actual:-<empty>}"
  fi
done
info "required staging config values match"

app_base_url="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.APP_BASE_URL}')"
auth_url="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.AUTH_URL}')"
mail_from="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.MAIL_FROM}')"

case "$app_base_url" in
  https://*) ;;
  *) fail "APP_BASE_URL must be https for real-provider staging" ;;
esac

case "$auth_url" in
  https://*) ;;
  *) fail "AUTH_URL must be https for real-provider staging" ;;
esac

case "$app_base_url $auth_url" in
  *".lan.e-dani.com"*) fail "staging OAuth URLs must not use LAN-only hostnames" ;;
esac

case "$mail_from" in
  *"@libreplay.local"*) fail "MAIL_FROM must not use @libreplay.local in staging" ;;
esac

info "staging URLs and MAIL_FROM look compatible with real providers"
info "contract check complete for namespace ${namespace}"
