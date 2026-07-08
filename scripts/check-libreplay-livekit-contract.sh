#!/usr/bin/env sh
set -eu

manifest="${1:-livekit/production-contract.yaml}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'OK: %s\n' "$*"
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if grep -Eq "$pattern" "$file"; then
    info "$description"
  else
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
  info "$description"
}

kubectl apply --dry-run=client --validate=false -f "$manifest" >/dev/null
kubectl kustomize livekit >/dev/null
info "LiveKit contract renders as Kubernetes YAML"

require_pattern "$manifest" 'name:[[:space:]]*libreplay-livekit[[:space:]]*$' 'LiveKit namespace is declared'
require_pattern "$manifest" 'name:[[:space:]]*libreplay-livekit-secrets[[:space:]]*$' 'LiveKit ExternalSecret is declared'
reject_pattern "$manifest" 'dataFrom:' 'LiveKit ExternalSecret does not bulk import secrets'

for key in LIVEKIT_API_KEY LIVEKIT_API_SECRET LIVEKIT_REDIS_PASSWORD LIVEKIT_S3_ENDPOINT LIVEKIT_S3_REGION LIVEKIT_S3_BUCKET LIVEKIT_S3_ACCESS_KEY LIVEKIT_S3_SECRET_KEY; do
  require_pattern "$manifest" "secretKey:[[:space:]]*${key}" "LiveKit ExternalSecret declares ${key}"
  require_pattern "$manifest" "property: ${key}" "LiveKit ExternalSecret maps ${key} by explicit property"
done
require_pattern "$manifest" 'key: secret/libreplay/production, property: LIVEKIT_API_KEY' 'LiveKit API key uses the same Vault path as the app contract'
require_pattern "$manifest" 'key: secret/libreplay/production, property: LIVEKIT_API_SECRET' 'LiveKit API secret uses the same Vault path as the app contract'

require_pattern "$manifest" 'livekit/livekit-server:v1\.9\.1@sha256:c039a1bfa154c8479ac369c380665638e92a7e9531e69664549c0c0d3eb65e63' 'LiveKit server image is immutable'
require_pattern "$manifest" 'livekit/egress:v1\.13\.0@sha256:980ff439431df2c773573721ab6da19e15bdc1f049ab7cb80e87470bf174c12f' 'LiveKit egress image is immutable'
require_pattern "$manifest" 'redis:7\.4-alpine@sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99' 'LiveKit Redis image is immutable'
reject_pattern "$manifest" 'image:[^@]*:latest' 'LiveKit contract does not use latest image tags'

for deployment in libreplay-livekit-redis libreplay-livekit-server libreplay-livekit-egress; do
  require_pattern "$manifest" "name:[[:space:]]*${deployment}" "deployment/service ${deployment} is declared"
done
require_pattern "$manifest" 'replicas:[[:space:]]*0' 'LiveKit contract is dormant until provider secrets and edge signoff'
require_pattern "$manifest" 'PersistentVolumeClaim' 'LiveKit Redis declares persistent storage'
require_pattern "$manifest" 'requirepass "\$LIVEKIT_REDIS_PASSWORD"' 'LiveKit Redis requires auth'
require_pattern "$manifest" 'password: \$\{LIVEKIT_REDIS_PASSWORD\}' 'LiveKit server/egress use Redis auth'
require_pattern "$manifest" 'port_range_start:[[:space:]]*50000' 'LiveKit RTC UDP range start is documented'
require_pattern "$manifest" 'port_range_end:[[:space:]]*60000' 'LiveKit RTC UDP range end is documented'
require_pattern "$manifest" 'containerPort:[[:space:]]*7880' 'LiveKit API port is exposed internally'
require_pattern "$manifest" 'containerPort:[[:space:]]*7881' 'LiveKit RTC TCP port is exposed internally'
require_pattern "$manifest" 'containerPort:[[:space:]]*50000' 'LiveKit RTC UDP contract port is declared'
require_pattern "$manifest" 'prometheus_port:[[:space:]]*6789' 'LiveKit server prometheus port is configured'
require_pattern "$manifest" 'health_port:[[:space:]]*7980' 'Egress health port is configured'
require_pattern "$manifest" 'prometheus_port:[[:space:]]*9090' 'Egress prometheus port is configured'
require_pattern "$manifest" 'kind:[[:space:]]*VMServiceScrape' 'LiveKit egress metrics scrape is declared'
require_pattern "$manifest" 'name:[[:space:]]*libreplay-livekit-server' 'LiveKit server metrics scrape is declared'
require_pattern "$manifest" 'resources:' 'LiveKit workloads declare resources'
require_pattern "$manifest" 'readinessProbe:' 'LiveKit workloads declare readiness probes'
require_pattern "$manifest" 'livenessProbe:' 'LiveKit workloads declare liveness probes'
require_pattern "$manifest" 'external-dns\.alpha\.kubernetes\.io/hostname:[[:space:]]*livekit\.e-dani\.com' 'LiveKit DNS preflight is declared'
require_pattern "$manifest" 'cloudflare-proxied:[[:space:]]*"false"' 'LiveKit DNS preflight is not Cloudflare-proxied for WebRTC'
reject_pattern "$manifest" 'kind:[[:space:]]*IngressRoute' 'LiveKit contract does not expose public ingress before signoff'
reject_pattern "$manifest" 'type:[[:space:]]*LoadBalancer' 'LiveKit contract does not allocate external load balancer before signoff'

info "LiveKit production contract check complete"
