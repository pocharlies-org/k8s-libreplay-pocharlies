#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
livekit_dir="$root_dir/livekit"
rendered="$(mktemp)"
document="$(mktemp)"
trap 'rm -f "$rendered" "$document"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

require_pattern() {
  pattern="$1"
  description="$2"
  grep -Eq "$pattern" "$rendered" || fail "$description"
  ok "$description"
}

reject_pattern() {
  pattern="$1"
  description="$2"
  if grep -Eq "$pattern" "$rendered"; then
    fail "$description"
  fi
  ok "$description"
}

extract_resource() {
  wanted_kind="$1"
  wanted_name="$2"
  awk -v wanted_kind="$wanted_kind" -v wanted_name="$wanted_name" '
    function flush() {
      if (doc_kind == wanted_kind && doc_name == wanted_name) {
        printf "%s", buffer
      }
      buffer = ""
      doc_kind = ""
      doc_name = ""
      in_metadata = 0
    }
    /^---$/ { flush(); next }
    {
      buffer = buffer $0 "\n"
      if ($0 ~ /^kind: /) {
        doc_kind = $0
        sub(/^kind: /, "", doc_kind)
      } else if ($0 == "metadata:") {
        in_metadata = 1
      } else if (in_metadata && $0 ~ /^  name: /) {
        doc_name = $0
        sub(/^  name: /, "", doc_name)
        in_metadata = 0
      }
    }
    END { flush() }
  ' "$rendered"
}

require_resource() {
  kind="$1"
  name="$2"
  extract_resource "$kind" "$name" >"$document"
  [ -s "$document" ] || fail "missing ${kind}/${name}"
  ok "${kind}/${name} is declared"
}

check_deployment() {
  name="$1"
  account="$2"
  extract_resource Deployment "$name" >"$document"
  [ -s "$document" ] || fail "missing Deployment/${name}"

  grep -Eq '^  replicas: 0$' "$document" || fail "Deployment/${name} must stay at replicas 0"
  grep -Eq "^[[:space:]]+serviceAccountName: ${account}$" "$document" || fail "Deployment/${name} must use ${account}"
  grep -Eq '^[[:space:]]+automountServiceAccountToken: false$' "$document" || fail "Deployment/${name} must disable token automount"
  grep -Eq '^[[:space:]]+runAsNonRoot: true$' "$document" || fail "Deployment/${name} must run as non-root"
  grep -Eq '^[[:space:]]+seccompProfile:$' "$document" || fail "Deployment/${name} must define seccomp"
  grep -Eq '^[[:space:]]+type: RuntimeDefault$' "$document" || fail "Deployment/${name} must use RuntimeDefault seccomp"
  grep -Eq '^[[:space:]]+allowPrivilegeEscalation: false$' "$document" || fail "Deployment/${name} must disable privilege escalation"
  grep -Eq '^[[:space:]]+drop:$' "$document" || fail "Deployment/${name} must define dropped capabilities"
  grep -Eq '^[[:space:]]+- ALL$' "$document" || fail "Deployment/${name} must drop all capabilities"
  grep -Eq '^[[:space:]]+readOnlyRootFilesystem: (true|false)$' "$document" || fail "Deployment/${name} must state its root filesystem compatibility"
  grep -Eq '^[[:space:]]+startupProbe:$' "$document" || fail "Deployment/${name} must define a startup probe"
  grep -Eq '^[[:space:]]+readinessProbe:$' "$document" || fail "Deployment/${name} must define a readiness probe"
  grep -Eq '^[[:space:]]+livenessProbe:$' "$document" || fail "Deployment/${name} must define a liveness probe"
  grep -Eq '^[[:space:]]+resources:$' "$document" || fail "Deployment/${name} must define resources"
  grep -Eq '^[[:space:]]+requests:$' "$document" || fail "Deployment/${name} must define resource requests"
  grep -Eq '^[[:space:]]+limits:$' "$document" || fail "Deployment/${name} must define resource limits"
  [ "$(grep -Ec '^[[:space:]]+cpu:' "$document")" -ge 2 ] || fail "Deployment/${name} must request and limit CPU"
  [ "$(grep -Ec '^[[:space:]]+memory:' "$document")" -ge 2 ] || fail "Deployment/${name} must request and limit memory"
  grep -Eq '^[[:space:]]+topologySpreadConstraints:$' "$document" || fail "Deployment/${name} must spread replicas"
  grep -Eq '^[[:space:]]+podAntiAffinity:$' "$document" || fail "Deployment/${name} must define anti-affinity"
  ok "Deployment/${name} is dormant and hardened"
}

kubectl kustomize "$livekit_dir" >"$rendered"
[ -s "$rendered" ] || fail "kubectl kustomize produced no output"
kubectl apply --dry-run=client --validate=false -f "$rendered" >/dev/null
ok "rendered contract passes kubectl client dry-run"

if command -v kubeconform >/dev/null 2>&1; then
  kubeconform_output="$(kubeconform -strict -summary -ignore-missing-schemas <"$rendered")"
  printf '%s\n' "$kubeconform_output"
  printf '%s\n' "$kubeconform_output" | grep -Eq 'Summary: [1-9][0-9]* resources? found' \
    || fail "kubeconform did not inspect rendered resources"
  ok "rendered contract passes kubeconform"
else
  printf 'SKIP: kubeconform is not installed\n'
fi

require_resource Namespace libreplay-livekit
for name in libreplay-livekit-secrets libreplay-livekit-turn-tls; do
  require_resource ExternalSecret "$name"
done

for name in libreplay-livekit-redis libreplay-livekit-server libreplay-livekit-egress libreplay-livekit-ingress; do
  require_resource ServiceAccount "$name"
  extract_resource ServiceAccount "$name" >"$document"
  grep -Eq '^automountServiceAccountToken: false$' "$document" || fail "ServiceAccount/${name} must disable token automount"
done
ok "all workload ServiceAccounts disable token automount"

check_deployment libreplay-livekit-redis libreplay-livekit-redis
check_deployment libreplay-livekit-server libreplay-livekit-server
check_deployment libreplay-livekit-egress libreplay-livekit-egress
check_deployment libreplay-livekit-ingress libreplay-livekit-ingress

for name in \
  libreplay-livekit-server \
  libreplay-livekit-egress \
  libreplay-livekit-ingress; do
  require_resource PodDisruptionBudget "$name"
done

for name in \
  libreplay-livekit-rtc-tcp \
  libreplay-livekit-rtc-udp \
  libreplay-livekit-turn-tls \
  libreplay-livekit-turn-udp \
  libreplay-livekit-rtmp \
  libreplay-livekit-whip \
  libreplay-livekit-whip-rtc; do
  require_resource Service "$name"
done

for name in \
  libreplay-livekit-default-deny \
  libreplay-livekit-dns \
  libreplay-livekit-redis \
  libreplay-livekit-server-ingress \
  libreplay-livekit-server-egress \
  libreplay-livekit-egress \
  libreplay-livekit-ingress; do
  require_resource NetworkPolicy "$name"
done

for pair in \
  'IngressRoute:libreplay-livekit-signal' \
  'IngressRoute:libreplay-livekit-whip' \
  'IngressRouteTCP:libreplay-livekit-rtc-tcp' \
  'IngressRouteTCP:libreplay-livekit-turn-tls' \
  'IngressRouteTCP:libreplay-livekit-rtmp' \
  'IngressRouteUDP:libreplay-livekit-rtc-udp' \
  'IngressRouteUDP:libreplay-livekit-turn-udp' \
  'IngressRouteUDP:libreplay-livekit-whip-rtc'; do
  require_resource "${pair%%:*}" "${pair#*:}"
done

for name in libreplay-livekit-server libreplay-livekit-egress libreplay-livekit-ingress; do
  require_resource VMServiceScrape "$name"
done

for key in \
  LIVEKIT_API_KEY LIVEKIT_API_SECRET LIVEKIT_REDIS_PASSWORD \
  LIVEKIT_S3_ENDPOINT LIVEKIT_S3_REGION LIVEKIT_S3_BUCKET \
  LIVEKIT_S3_ACCESS_KEY LIVEKIT_S3_SECRET_KEY \
  LIVEKIT_TURN_TLS_CRT LIVEKIT_TURN_TLS_KEY; do
  require_pattern "property: ${key}" "ExternalSecret maps ${key} explicitly"
done
reject_pattern '^[[:space:]]*dataFrom:' 'ExternalSecrets must not bulk import secrets'

image_count="$(grep -Ec '^[[:space:]]*image:' "$rendered")"
[ "$image_count" -eq 4 ] || fail "expected exactly 4 workload images, found ${image_count}"
if grep -E '^[[:space:]]*image:' "$rendered" | grep -Ev '@sha256:[0-9a-f]{64}$' >/dev/null; then
  fail "every workload image must end in an immutable sha256 digest"
fi
ok "all four workload images use immutable sha256 digests"
require_pattern 'image: redis:7\.4-alpine@sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99' 'Redis image digest matches the reviewed artifact'
require_pattern 'image: livekit/livekit-server:v1\.9\.1@sha256:c039a1bfa154c8479ac369c380665638e92a7e9531e69664549c0c0d3eb65e63' 'LiveKit Server image digest matches the reviewed artifact'
require_pattern 'image: livekit/egress:v1\.13\.0@sha256:980ff439431df2c773573721ab6da19e15bdc1f049ab7cb80e87470bf174c12f' 'LiveKit Egress image digest matches the reviewed artifact'
require_pattern 'image: livekit/ingress:v1\.4\.3@sha256:04bdc68b56530870e65086a07daac7743f3f049f0be87e0df2b4b7e51f1b9379' 'LiveKit Ingress image digest matches the reviewed artifact'

reject_pattern 'image:[^[:space:]]*:latest(@|[[:space:]]|$)' 'latest image tags are forbidden'
reject_pattern '^  replicas: [1-9][0-9]*$' 'active replicas are forbidden'
reject_pattern '^kind: (DaemonSet|StatefulSet|Job|CronJob|HorizontalPodAutoscaler)$' 'unexpected active workload kinds are forbidden'
reject_pattern '^  type: (LoadBalancer|NodePort)$' 'externally allocating Service types are forbidden before activation'
require_pattern 'libreplay\.e-dani\.com/activation: blocked-pending-provider-secrets-and-edge-signoff' 'namespace activation remains blocked'
[ "$(grep -Ec 'libreplay\.e-dani\.com/activation: blocked$' "$rendered")" -eq 8 ] \
  || fail "all eight edge routes must remain activation-blocked"
ok "all eight edge routes remain activation-blocked"

for port in 53 443 1935 3478 5349 6379 6789 7880 7881 7885 7889 8080 9090 50000; do
  require_pattern "port: ${port}([,}]|$)" "network/edge contract declares port ${port}"
done
for edge_ip in 100.107.21.89 100.71.117.127 100.75.189.75 100.109.183.9; do
  edge_ip_pattern="$(printf '%s' "$edge_ip" | sed 's/\./\\./g')"
  require_pattern "cidr: ${edge_ip_pattern}/32" "NetworkPolicies allow audited hostNetwork edge node ${edge_ip}"
done
require_pattern 'minAvailable: 1' 'disruption budgets retain one replica after future activation'
require_pattern 'storage:' 'egress storage block is declared'
require_pattern 'force_path_style: true' 'S3-compatible path-style uploads are explicit'
reject_pattern 'file_outputs:' 'invalid egress service-level file_outputs config is forbidden'
require_pattern 'enable_chrome_sandbox: false' 'egress Chrome sandbox compatibility is explicit'
require_pattern 'turn:' 'embedded TURN config is declared'
require_pattern 'tls_port: 5349' 'TURN/TLS port is configured'
require_pattern 'udp_port: 3478' 'TURN/UDP port is configured'
require_pattern 'rtmp_base_url: rtmp://ingest\.livekit\.e-dani\.com/live' 'OBS RTMP base URL is configured'
require_pattern 'whip_base_url: https://ingest\.livekit\.e-dani\.com/w' 'OBS WHIP base URL is configured'
require_pattern 'node_ip: 57\.129\.17\.172' 'RTC candidates use the reviewed public edge IP'
reject_pattern 'use_external_ip: true' 'RTC public IP autodetection is forbidden behind the edge proxy'

ok "LiveKit production contract is strict, dormant, and ready for review"
