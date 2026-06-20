#!/usr/bin/env sh
set -eu

overlay="${1:-staging/overlays/runtime}"
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'OK: %s\n' "$*"
}

require_pattern() {
  pattern="$1"
  message="$2"
  if ! grep -Eq "$pattern" "$rendered"; then
    fail "$message"
  fi
  info "$message"
}

reject_pattern() {
  pattern="$1"
  message="$2"
  if grep -Eq "$pattern" "$rendered"; then
    fail "$message"
  fi
  info "$message"
}

kubectl kustomize "$overlay" > "$rendered"
kubectl apply --dry-run=client -f "$rendered" >/dev/null
info "staging runtime overlay renders and passes client dry-run"

require_pattern 'name:[[:space:]]*libreplay-staging' 'staging namespace is rendered'
require_pattern 'namespace:[[:space:]]*libreplay-staging' 'all namespaced resources target libreplay-staging'
reject_pattern 'namespace:[[:space:]]*libreplay[[:space:]]*$' 'no namespaced resource targets the LAN namespace'

require_pattern 'DEPLOYMENT_MODE:[[:space:]]*staging' 'DEPLOYMENT_MODE is staging'
require_pattern 'NODE_ENV:[[:space:]]*production' 'NODE_ENV is production'
require_pattern 'USE_MOCK_OAUTH:[[:space:]]*"?false"?' 'mock OAuth is disabled'
require_pattern 'AUTH_EMAIL_PROVIDER:[[:space:]]*smtp' 'auth email provider is SMTP'
require_pattern 'PAYMENT_PROVIDER:[[:space:]]*disabled' 'payments are disabled until a real PSP exists'
require_pattern 'ENABLE_MOCK_PAYMENTS:[[:space:]]*"?false"?' 'mock payments are disabled'
require_pattern 'ENABLE_LAN_DEMO_LOGIN:[[:space:]]*"?false"?' 'LAN demo login is disabled'
require_pattern 'APP_BASE_URL:[[:space:]]*https://libreplay-staging\.e-dani\.com' 'APP_BASE_URL uses the staging HTTPS host'
require_pattern 'AUTH_URL:[[:space:]]*https://libreplay-staging\.e-dani\.com' 'AUTH_URL uses the staging HTTPS host'
require_pattern 'Host\(`libreplay-staging\.e-dani\.com`\)' 'IngressRoute uses the staging host'
require_pattern 'POSTGRES_DB[[:space:]]*$' 'Postgres DB env exists'
require_pattern 'libreplay_staging' 'staging database name is rendered'
require_pattern 'key:[[:space:]]*secret/libreplay/staging' 'ExternalSecret reads from the staging Vault path'

for key in \
  DATABASE_URL REDIS_URL AUTH_SECRET MINIO_ACCESS_KEY MINIO_SECRET_KEY \
  MEILISEARCH_API_KEY DB_USER DB_PASSWORD SEED_USER_PASSWORD \
  GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET FACEBOOK_CLIENT_ID \
  FACEBOOK_CLIENT_SECRET OAUTH_TOKEN_ENC_KEY SMTP_HOST SMTP_PORT \
  SMTP_USER SMTP_PASSWORD
do
  require_pattern "secretKey:[[:space:]]*${key}[[:space:]]*$" "ExternalSecret declares ${key}"
done

reject_pattern 'DEPLOYMENT_MODE:[[:space:]]*lan-demo' 'DEPLOYMENT_MODE is not LAN demo'
reject_pattern 'USE_MOCK_OAUTH:[[:space:]]*"?true"?' 'mock OAuth is not enabled'
reject_pattern 'AUTH_EMAIL_PROVIDER:[[:space:]]*console' 'console auth email is not enabled'
reject_pattern 'PAYMENT_PROVIDER:[[:space:]]*mock' 'mock payments provider is not enabled'
reject_pattern 'ENABLE_MOCK_PAYMENTS:[[:space:]]*"?true"?' 'mock payments flag is not enabled'
reject_pattern 'ENABLE_LAN_DEMO_LOGIN:[[:space:]]*"?true"?' 'LAN demo login flag is not enabled'
reject_pattern 'libreplay\.lan\.e-dani\.com' 'LAN host is absent from staging runtime'
reject_pattern 'libreplay_lan' 'LAN database name is absent from staging runtime'
reject_pattern 'key:[[:space:]]*secret/libreplay[[:space:]]*$' 'base LAN Vault path is absent'
reject_pattern 'dataFrom:' 'ExternalSecret does not bulk-import the LAN secret shape'
reject_pattern 'optional:[[:space:]]*true' 'provider and SMTP secret refs are not optional in staging'
reject_pattern 'ClientIP\(' 'staging ingress is not LAN-IP gated'
reject_pattern 'sso-chain' 'staging app auth is not hidden behind the LAN SSO middleware'

info "staging runtime check complete for ${overlay}"
