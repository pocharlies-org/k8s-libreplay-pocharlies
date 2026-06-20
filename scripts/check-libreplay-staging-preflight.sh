#!/usr/bin/env sh
set -eu

namespace="${NAMESPACE:-libreplay-staging}"
app="${ARGO_APP:-libreplay-staging}"
host="${STAGING_HOST:-libreplay-staging.e-dani.com}"
mode="${1:-report}"

failures=0
blockers=0

ok() {
  printf 'OK: %s\n' "$*"
}

block() {
  blockers=$((blockers + 1))
  printf 'BLOCKED: %s\n' "$*" >&2
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

secret_keys="
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
"

config_pairs="
NODE_ENV=production
DEPLOYMENT_MODE=staging
USE_MOCK_OAUTH=false
AUTH_EMAIL_PROVIDER=smtp
PAYMENT_PROVIDER=disabled
ENABLE_MOCK_PAYMENTS=false
ENABLE_LAN_DEMO_LOGIN=false
TRUST_PROXY_CLIENT_IP=true
TRUSTED_CLIENT_IP_HEADER=cf-connecting-ip
"

scripts/check-libreplay-staging-contract.sh --static >/dev/null
scripts/check-libreplay-staging-runtime.sh >/dev/null
ok "static contract and runtime overlay render without LAN drift"

if kubectl -n argocd get application "$app" >/dev/null 2>&1; then
  app_status="$(kubectl -n argocd get application "$app" -o 'jsonpath={.status.sync.status}|{.status.health.status}|{.status.sync.revision}|{.spec.source.path}')"
  ok "Argo app ${app} exists: ${app_status}"
  app_path="$(printf '%s' "$app_status" | awk -F'|' '{print $4}')"
  if [ "$app_path" != "staging" ]; then
    fail "Argo app ${app} must remain on contract-only path staging before runtime preflight passes"
  fi
else
  block "Argo app ${app} is missing"
fi

if kubectl get namespace "$namespace" >/dev/null 2>&1; then
  ok "namespace ${namespace} exists"
else
  block "namespace ${namespace} is missing"
fi

runtime_resources="$(kubectl -n "$namespace" get deploy,sts,job,ingressroute,svc,pod --ignore-not-found -o name 2>/dev/null \
  | grep -Fxv 'service/libreplay-staging-dns-preflight' || true)"
if [ -n "$runtime_resources" ]; then
  fail "runtime resources exist in ${namespace}; keep staging contract-only until preflight is strict-green"
else
  ok "no runtime workloads/services/ingress are present in ${namespace}"
fi

if kubectl -n "$namespace" get service libreplay-staging-dns-preflight >/dev/null 2>&1; then
  dns_service_type="$(kubectl -n "$namespace" get service libreplay-staging-dns-preflight -o 'jsonpath={.spec.type}')"
  dns_host="$(kubectl -n "$namespace" get service libreplay-staging-dns-preflight -o 'jsonpath={.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}')"
  dns_target="$(kubectl -n "$namespace" get service libreplay-staging-dns-preflight -o 'jsonpath={.metadata.annotations.external-dns\.alpha\.kubernetes\.io/target}')"
  dns_proxied="$(kubectl -n "$namespace" get service libreplay-staging-dns-preflight -o 'jsonpath={.metadata.annotations.external-dns\.alpha\.kubernetes\.io/cloudflare-proxied}')"
  if [ "$dns_service_type" = "ExternalName" ] && [ "$dns_host" = "$host" ] && [ "$dns_target" = "57.129.17.172" ] && [ "$dns_proxied" = "true" ]; then
    ok "DNS preflight service is present for ${host}"
  else
    fail "DNS preflight service has unexpected type/annotations"
  fi
else
  block "DNS preflight service is missing in ${namespace}"
fi

if kubectl -n "$namespace" get configmap libreplay-config >/dev/null 2>&1; then
  for pair in $config_pairs; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(kubectl -n "$namespace" get configmap libreplay-config -o "jsonpath={.data.${key}}")"
    if [ "$actual" = "$expected" ]; then
      ok "ConfigMap libreplay-config/${key}=${expected}"
    else
      fail "ConfigMap libreplay-config/${key} expected ${expected}, got ${actual:-<empty>}"
    fi
  done
else
  block "ConfigMap libreplay-config is missing in ${namespace}"
fi

if kubectl -n "$namespace" get externalsecret libreplay-secrets >/dev/null 2>&1; then
  condition="$(kubectl -n "$namespace" get externalsecret libreplay-secrets -o 'jsonpath={range .status.conditions[*]}{.type}|{.status}|{.reason}|{.message}{end}')"
  case "$condition" in
    Ready\|True*) ok "ExternalSecret libreplay-secrets is Ready=True" ;;
    *) block "ExternalSecret libreplay-secrets is not ready: ${condition:-<no condition>}" ;;
  esac
else
  block "ExternalSecret libreplay-secrets is missing in ${namespace}"
fi

if kubectl -n "$namespace" get secret libreplay-secrets >/dev/null 2>&1; then
  tmp_keys="$(mktemp)"
  kubectl -n "$namespace" get secret libreplay-secrets \
    -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' \
    | sort > "$tmp_keys"
  for key in $secret_keys; do
    if grep -Fx "$key" "$tmp_keys" >/dev/null; then
      ok "Secret libreplay-secrets contains key ${key}"
    else
      block "Secret libreplay-secrets missing key ${key}"
    fi
  done
  rm -f "$tmp_keys"
else
  block "Secret libreplay-secrets is not materialized in ${namespace}"
fi

if kubectl -n "$namespace" get externalsecret harbor-pull >/dev/null 2>&1; then
  condition="$(kubectl -n "$namespace" get externalsecret harbor-pull -o 'jsonpath={range .status.conditions[*]}{.type}|{.status}|{.reason}|{.message}{end}')"
  case "$condition" in
    Ready\|True*) ok "ExternalSecret harbor-pull is Ready=True" ;;
    *) block "ExternalSecret harbor-pull is not ready: ${condition:-<no condition>}" ;;
  esac
else
  block "ExternalSecret harbor-pull is missing in ${namespace}"
fi

if kubectl -n "$namespace" get secret harbor-pull >/dev/null 2>&1; then
  pull_type="$(kubectl -n "$namespace" get secret harbor-pull -o 'jsonpath={.type}')"
  if [ "$pull_type" = "kubernetes.io/dockerconfigjson" ]; then
    ok "Secret harbor-pull has dockerconfigjson type"
  else
    fail "Secret harbor-pull has unexpected type ${pull_type:-<empty>}"
  fi
  if kubectl -n "$namespace" get secret harbor-pull \
    -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' \
    | grep -Fx '.dockerconfigjson' >/dev/null; then
    ok "Secret harbor-pull contains .dockerconfigjson key"
  else
    fail "Secret harbor-pull is missing .dockerconfigjson key"
  fi
else
  block "Secret harbor-pull is not materialized in ${namespace}"
fi

if getent hosts "$host" >/dev/null 2>&1; then
  ok "DNS resolves for ${host}"
  if python3 - "$host" <<'PY'
import socket
import ssl
import sys

host = sys.argv[1]
ctx = ssl.create_default_context()
with socket.create_connection((host, 443), timeout=5) as sock:
    with ctx.wrap_socket(sock, server_hostname=host):
        pass
PY
  then
    ok "TLS handshake validates for ${host}"
  else
    block "TLS handshake does not validate for ${host}"
  fi
else
  block "DNS does not resolve for ${host}"
fi

if [ "$failures" -gt 0 ]; then
  printf 'FAIL: staging preflight found %s hard failure(s) and %s blocker(s)\n' "$failures" "$blockers" >&2
  exit 1
fi

if [ "$blockers" -gt 0 ]; then
  printf 'BLOCKED: staging preflight found %s blocker(s)\n' "$blockers" >&2
  if [ "$mode" = "--strict" ] || [ "$mode" = "strict" ]; then
    exit 1
  fi
  exit 0
fi

ok "staging preflight complete"
