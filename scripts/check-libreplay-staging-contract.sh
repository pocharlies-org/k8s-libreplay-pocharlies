#!/usr/bin/env sh
set -eu

mode="live"
manifest="staging/libreplay-staging-contract.yaml"
namespace="${1:-${NAMESPACE:-libreplay-staging}}"

if [ "${1:-}" = "--static" ]; then
  mode="static"
  manifest="${2:-$manifest}"
  namespace="${NAMESPACE:-libreplay-staging}"
fi

secret_name="${SECRET_NAME:-libreplay-secrets}"
pull_secret_name="${PULL_SECRET_NAME:-harbor-pull}"
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

yaml_value() {
  key="$1"
  awk -v key="$key" '
    $1 == key ":" {
      sub("^[^:]*:[[:space:]]*", "")
      gsub(/^"|"$/, "")
      print
    }
  ' "$manifest" | tail -n 1
}

check_urls_and_mail() {
  app_base_url="$1"
  auth_url="$2"
  mail_from="$3"

  case "$app_base_url" in
    https://*) ;;
    *) fail "APP_BASE_URL must be https for real-provider staging" ;;
  esac

  case "$auth_url" in
    https://*) ;;
    *) fail "AUTH_URL must be https for real-provider staging" ;;
  esac

  case "$app_base_url $auth_url" in
    *example.com*) fail "staging OAuth URLs must not use example.com placeholders" ;;
    *".lan.e-dani.com"*) fail "staging OAuth URLs must not use LAN-only hostnames" ;;
    *".local"*) fail "staging OAuth URLs must not use local-only hostnames" ;;
  esac

  case "$mail_from" in
    *"@libreplay.local"*) fail "MAIL_FROM must not use @libreplay.local in staging" ;;
    *example.com*) fail "MAIL_FROM must not use example.com placeholder domains" ;;
  esac
}

if [ "$mode" = "static" ]; then
  kubectl apply --dry-run=client -f "$manifest" >/dev/null

  for key in $required_secret_keys; do
    if ! grep -Eq "^[[:space:]]*-[[:space:]]*secretKey:[[:space:]]*${key}[[:space:]]*$" "$manifest"; then
      fail "static contract missing ExternalSecret key ${key}"
    fi
  done
  info "static contract declares required ExternalSecret key names; values were not printed"

  if ! grep -Eq '^[[:space:]]*name:[[:space:]]*harbor-pull[[:space:]]*$' "$manifest"; then
    fail "static contract missing ExternalSecret harbor-pull"
  fi
  if ! grep -Eq 'type:[[:space:]]*kubernetes\.io/dockerconfigjson' "$manifest"; then
    fail "static contract missing dockerconfigjson template for harbor-pull"
  fi
  for key in username password registry; do
    if ! grep -Eq "remoteRef:[[:space:]]*\\{ key: infra/harbor/ci-robot, property: ${key} \\}" "$manifest"; then
      fail "static contract missing harbor-pull remoteRef ${key}"
    fi
  done
  info "static contract declares harbor-pull ExternalSecret without printing registry credentials"

  for pair in $required_config_values; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(yaml_value "$key")"
    if [ "$actual" != "$expected" ]; then
      fail "static contract config ${key} expected ${expected}, got ${actual:-<empty>}"
    fi
  done
  info "static contract required staging config values match"

  check_urls_and_mail "$(yaml_value APP_BASE_URL)" "$(yaml_value AUTH_URL)" "$(yaml_value MAIL_FROM)"
  info "static staging URLs and MAIL_FROM look compatible with real providers"
  info "static contract check complete for ${manifest}"
  exit 0
fi

if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
  fail "namespace ${namespace} does not exist; apply or sync the staging contract before live validation"
fi

kubectl -n "$namespace" get secret "$secret_name" \
  -o go-template='{{range $k, $v := .data}}{{printf "%s\n" $k}}{{end}}' \
  | sort > "$tmp_keys"

for key in $required_secret_keys; do
  if ! grep -Fx "$key" "$tmp_keys" >/dev/null; then
    fail "missing secret key ${secret_name}/${key} in namespace ${namespace}"
  fi
done
info "required secret key names exist in ${namespace}/${secret_name}; values were not printed"

if ! kubectl -n "$namespace" get secret "$pull_secret_name" >/dev/null 2>&1; then
  fail "missing image pull secret ${namespace}/${pull_secret_name}"
fi
pull_secret_type="$(kubectl -n "$namespace" get secret "$pull_secret_name" -o 'jsonpath={.type}')"
if [ "$pull_secret_type" != "kubernetes.io/dockerconfigjson" ]; then
  fail "image pull secret ${namespace}/${pull_secret_name} has type ${pull_secret_type:-<empty>}"
fi
if ! kubectl -n "$namespace" get secret "$pull_secret_name" \
  -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' \
  | grep -Fx '.dockerconfigjson' >/dev/null; then
  fail "image pull secret ${namespace}/${pull_secret_name} is missing .dockerconfigjson"
fi
info "image pull secret ${namespace}/${pull_secret_name} exists with dockerconfigjson key; value was not printed"

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
check_urls_and_mail "$app_base_url" "$auth_url" "$mail_from"
info "staging URLs and MAIL_FROM look compatible with real providers"
info "contract check complete for namespace ${namespace}"
