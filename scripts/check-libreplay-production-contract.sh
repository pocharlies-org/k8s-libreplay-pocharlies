#!/usr/bin/env sh
set -eu

mode="static"
manifest="production/libreplay-production-contract.yaml"
namespace="${NAMESPACE:-libreplay-production}"
secret_name="${SECRET_NAME:-libreplay-secrets}"
pull_secret_name="${PULL_SECRET_NAME:-harbor-pull}"
config_name="${CONFIG_NAME:-libreplay-config}"

if [ "${1:-}" = "--live" ]; then
  mode="live"
  namespace="${2:-$namespace}"
elif [ "${1:-}" = "--static" ]; then
  mode="static"
  manifest="${2:-$manifest}"
elif [ -n "${1:-}" ]; then
  manifest="$1"
fi

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
YOTI_AGE_API_KEY
YOTI_AGE_SDK_ID
YOTI_AGE_CALLBACK_URL
YOTI_AGE_CANCEL_URL
YOTI_IDV_CLIENT_SDK_ID
YOTI_IDV_PRIVATE_KEY
HIVE_API_KEY
HIVE_REJECT_CLASSES
HIVE_REVIEW_CLASSES
SMTP_HOST
SMTP_PORT
SMTP_USER
SMTP_PASSWORD
METRICS_BEARER_TOKEN
LIVEKIT_API_KEY
LIVEKIT_API_SECRET
LIVE_STREAM_SIGNING_KEY
"

required_config_values="
NODE_ENV=production
DEPLOYMENT_MODE=production
USE_MOCK_OAUTH=false
PAYMENT_PROVIDER=disabled
ENABLE_MOCK_PAYMENTS=false
AGE_VERIFICATION_PROVIDER=yoti
FACE_LIVENESS_PROVIDER=yoti
CSAM_SCANNER_PROVIDER=thorn-safer
MEDIA_MODERATION_PROVIDER=hive
ENABLE_MOCK_AGE_VERIFICATION=false
ENABLE_MOCK_FACE_LIVENESS=false
ENABLE_MOCK_CSAM_SCANNER=false
ENABLE_MOCK_MEDIA_MODERATION=false
ENABLE_MOCK_LLM=false
AUTH_EMAIL_PROVIDER=smtp
ENABLE_LAN_DEMO_LOGIN=false
TRUST_PROXY_CLIENT_IP=true
TRUSTED_CLIENT_IP_HEADER=cf-connecting-ip
LIVE_STREAM_PROVIDER=livekit
LIVEKIT_EGRESS_ENABLED=true
LIVE_STREAM_DELIVERY_MODE=signed-cdn
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
  minio_public_url="$4"

  [ "$app_base_url" = "https://libreplay.e-dani.com" ] || fail "APP_BASE_URL must be the production HTTPS host"
  [ "$auth_url" = "https://libreplay.e-dani.com" ] || fail "AUTH_URL must be the production HTTPS host"

  case "$app_base_url $auth_url $minio_public_url" in
    *example.com*) fail "production URLs must not use example.com placeholders" ;;
    *".lan.e-dani.com"*) fail "production URLs must not use LAN-only hostnames" ;;
    *"libreplay-staging.e-dani.com"*) fail "production URLs must not use staging hostnames" ;;
    *".local"*) fail "production URLs must not use local-only hostnames" ;;
    *".svc.cluster.local"*) fail "public production URLs must not use cluster-local hostnames" ;;
  esac

  case "$minio_public_url" in
    https://*) ;;
    *) fail "MINIO_PUBLIC_URL must be https in production contract" ;;
  esac

  case "$mail_from" in
    *"@libreplay.local"*) fail "MAIL_FROM must not use @libreplay.local in production" ;;
    *example.com*) fail "MAIL_FROM must not use example.com placeholder domains" ;;
  esac
}

check_static() {
  kubectl apply --dry-run=client -f "$manifest" >/dev/null
  kubectl kustomize production >/dev/null

  for forbidden in 'kind:[[:space:]]*Deployment' 'kind:[[:space:]]*StatefulSet' 'kind:[[:space:]]*IngressRoute' 'kind:[[:space:]]*Job' 'kind:[[:space:]]*CronJob'; do
    if grep -Eq "$forbidden" "$manifest"; then
      fail "production contract must not define runtime workload or ingress resources"
    fi
  done
  info "production contract is contract-only; no workloads or ingress are defined"

  for key in $required_secret_keys; do
    if ! grep -Eq "^[[:space:]]*-[[:space:]]*secretKey:[[:space:]]*${key}[[:space:]]*$" "$manifest"; then
      fail "static production contract missing ExternalSecret key ${key}"
    fi
    if ! grep -Eq "remoteRef:[[:space:]]*\\{ key: secret/libreplay/production, property: ${key} \\}" "$manifest"; then
      fail "static production contract ${key} must read from secret/libreplay/production"
    fi
  done
  info "production contract declares required ExternalSecret key names at secret/libreplay/production"

  if grep -Eq 'dataFrom:' "$manifest"; then
    fail "production contract must not bulk-import the LAN secret shape"
  fi
  info "production contract uses explicit secret keys, not dataFrom"

  if ! grep -Eq '^[[:space:]]*name:[[:space:]]*harbor-pull[[:space:]]*$' "$manifest"; then
    fail "production contract missing ExternalSecret harbor-pull"
  fi
  if ! grep -Eq 'type:[[:space:]]*kubernetes\.io/dockerconfigjson' "$manifest"; then
    fail "production contract missing dockerconfigjson template for harbor-pull"
  fi
  if ! grep -Eq 'remoteRef:[[:space:]]*\{ key: infra/harbor/k8s-runtime-pull, property: dockerconfigjson \}' "$manifest"; then
    fail "production contract missing pull-only harbor-pull remoteRef"
  fi
  info "production contract declares harbor-pull ExternalSecret without printing registry credentials"

  for pattern in \
    'name:[[:space:]]*libreplay-production-dns-preflight' \
    'external-dns\.alpha\.kubernetes\.io/hostname:[[:space:]]*libreplay\.e-dani\.com' \
    'external-dns\.alpha\.kubernetes\.io/target:[[:space:]]*57\.129\.17\.172' \
    'external-dns\.alpha\.kubernetes\.io/cloudflare-proxied:[[:space:]]*"true"' \
    'type:[[:space:]]*ExternalName'; do
    if ! grep -Eq "$pattern" "$manifest"; then
      fail "static production contract missing DNS preflight pattern: ${pattern}"
    fi
  done
  info "production contract declares DNS-only preflight service for external-dns"

  for pair in $required_config_values; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(yaml_value "$key")"
    if [ "$actual" != "$expected" ]; then
      fail "static production config ${key} expected ${expected}, got ${actual:-<empty>}"
    fi
  done
  info "static production config required values match"

  check_urls_and_mail "$(yaml_value APP_BASE_URL)" "$(yaml_value AUTH_URL)" "$(yaml_value MAIL_FROM)" "$(yaml_value MINIO_PUBLIC_URL)"
  info "static production URLs, media URL and MAIL_FROM look compatible with real providers"
}

check_live() {
  if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
    fail "namespace ${namespace} does not exist; sync the production contract before live validation"
  fi

  kubectl -n "$namespace" get secret "$secret_name" \
    -o go-template='{{range $k, $v := .data}}{{printf "%s\n" $k}}{{end}}' \
    | sort > "$tmp_keys"

  for key in $required_secret_keys; do
    if ! grep -Fx "$key" "$tmp_keys" >/dev/null; then
      fail "missing secret key ${secret_name}/${key} in namespace ${namespace}"
    fi
  done
  info "required production secret key names exist in ${namespace}/${secret_name}; values were not printed"

  if ! kubectl -n "$namespace" get secret "$pull_secret_name" >/dev/null 2>&1; then
    fail "missing image pull secret ${namespace}/${pull_secret_name}"
  fi
  pull_secret_type="$(kubectl -n "$namespace" get secret "$pull_secret_name" -o 'jsonpath={.type}')"
  [ "$pull_secret_type" = "kubernetes.io/dockerconfigjson" ] || fail "image pull secret ${namespace}/${pull_secret_name} has type ${pull_secret_type:-<empty>}"
  info "image pull secret ${namespace}/${pull_secret_name} exists with dockerconfigjson type"

  for pair in $required_config_values; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(kubectl -n "$namespace" get configmap "$config_name" -o "jsonpath={.data.${key}}")"
    if [ "$actual" != "$expected" ]; then
      fail "config ${config_name}/${key} expected ${expected}, got ${actual:-<empty>}"
    fi
  done
  info "required production config values match"

  app_base_url="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.APP_BASE_URL}')"
  auth_url="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.AUTH_URL}')"
  mail_from="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.MAIL_FROM}')"
  minio_public_url="$(kubectl -n "$namespace" get configmap "$config_name" -o 'jsonpath={.data.MINIO_PUBLIC_URL}')"
  check_urls_and_mail "$app_base_url" "$auth_url" "$mail_from" "$minio_public_url"
  info "production URLs, media URL and MAIL_FROM look compatible with real providers"
}

if [ "$mode" = "live" ]; then
  check_live
else
  check_static
fi

info "production contract check complete"
