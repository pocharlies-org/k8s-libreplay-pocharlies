#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
vmprobe="$root/k8s/vmprobe.yaml"
vmrule="$root/k8s/vmrule.yaml"
kustomization="$root/k8s/kustomization.yaml"
staging_kustomization="$root/staging/overlays/runtime/kustomization.yaml"
staging_remove_patch="$root/staging/overlays/runtime/patch-remove-lan-synthetics-vmrule.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  grep -Eq "$pattern" "$file" || fail "$description"
}

reject_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if grep -Eq "$pattern" "$file"; then
    fail "$description"
  fi
}

[ -f "$vmprobe" ] || fail "missing k8s/vmprobe.yaml"
[ -f "$vmrule" ] || fail "missing k8s/vmrule.yaml"
[ -f "$kustomization" ] || fail "missing k8s/kustomization.yaml"
[ -f "$staging_kustomization" ] || fail "missing staging runtime kustomization"
[ -f "$staging_remove_patch" ] || fail "missing staging runtime patch-remove-lan-synthetics-vmrule.json"

kubectl apply --dry-run=client -f "$vmprobe" >/dev/null
ok "VMProbe contract is valid Kubernetes YAML"

require_pattern "$vmprobe" '^kind:[[:space:]]*VMProbe[[:space:]]*$' "synthetic resource must be a VMProbe"
require_pattern "$vmprobe" 'name:[[:space:]]*libreplay-lan-synthetic[[:space:]]*$' "VMProbe name must be libreplay-lan-synthetic"
require_pattern "$vmprobe" 'namespace:[[:space:]]*monitoring[[:space:]]*$' "VMProbe must live in monitoring namespace"
require_pattern "$vmprobe" 'jobName:[[:space:]]*libreplay-lan-synthetic[[:space:]]*$' "VMProbe jobName must be libreplay-lan-synthetic"
require_pattern "$vmprobe" 'module:[[:space:]]*http_alive_tls[[:space:]]*$' "VMProbe must use TLS-validating blackbox module"
require_pattern "$vmprobe" 'url:[[:space:]]*blackbox-exporter\.monitoring\.svc\.cluster\.local:9115[[:space:]]*$' "VMProbe must use in-cluster blackbox exporter"
require_pattern "$vmprobe" 'https://libreplay\.lan\.e-dani\.com/api/health' "VMProbe must target shallow LAN health endpoint"
require_pattern "$vmprobe" 'endpoint:[[:space:]]*health[[:space:]]*$' "VMProbe must label endpoint=health"
reject_pattern "$vmprobe" 'bearerTokenSecret|authorization|basicAuth|oauth2|insecure_skip_verify|/api/health/deps' "VMProbe must not use auth, disable TLS verify or probe /deps"
ok "VMProbe target, labels and security posture look correct"

require_pattern "$kustomization" 'vmprobe\.yaml' "k8s/kustomization.yaml must include vmprobe.yaml"
require_pattern "$staging_kustomization" 'patch-delete-lan-vmprobe\.yaml' "staging runtime must delete inherited LAN VMProbe"
ok "kustomizations wire prod probe and staging deletion guard"

tmp_group="$(mktemp)"
tmp_slo_group="$(mktemp)"
tmp_base="$(mktemp)"
tmp_staging="$(mktemp)"
trap 'rm -f "$tmp_group" "$tmp_slo_group" "$tmp_base" "$tmp_staging"' EXIT

awk '
  /name:[[:space:]]*libreplay\.synthetics[[:space:]]*$/ { capture=1 }
  capture { print }
' "$vmrule" > "$tmp_group"

for alert in LibrePlaySyntheticDown LibrePlaySyntheticLatencyHigh LibrePlaySyntheticAvailabilityBudgetLow; do
  require_pattern "$tmp_group" "alert:[[:space:]]*${alert}[[:space:]]*$" "VMRule missing ${alert}"
done
require_pattern "$vmrule" 'name:[[:space:]]*libreplay\.synthetics[[:space:]]*$' "VMRule missing libreplay.synthetics group"
require_pattern "$tmp_group" 'probe_success\{job="libreplay-lan-synthetic",app="libreplay",endpoint="health"\}' "VMRule must target the LibrePlay synthetic health probe"
reject_pattern "$tmp_group" 'response body|/api/health/deps|bearerTokenSecret|authorization' "VMRule synthetic group must not leak body/deps/auth details"
ok "VMRule synthetic alerts are present and scoped"

# --- SLO group (libreplay.slo) contract ------------------------------------
# `severity: warning` is silently blackholed by the shared Alertmanager default
# route; LibrePlay alerts must use warn/critical only.
reject_pattern "$vmrule" 'severity:[[:space:]]*warning([[:space:]]|$)' "k8s/vmrule.yaml must not use severity: warning (blackholed by shared route; use warn/critical)"
ok "VMRule uses no blackholed severity: warning label"

require_pattern "$vmrule" 'name:[[:space:]]*libreplay\.slo[[:space:]]*$' "VMRule missing libreplay.slo group"

awk '
  /name:[[:space:]]*libreplay\.slo[[:space:]]*$/ { capture=1 }
  capture { print }
' "$vmrule" > "$tmp_slo_group"

for record in \
  'libreplay:slo_synth_avail:ratio5m' \
  'libreplay:slo_synth_avail:ratio30m' \
  'libreplay:slo_synth_avail:ratio1h' \
  'libreplay:slo_synth_avail:ratio6h' \
  'libreplay:slo_synth_avail:ratio3d' \
  'libreplay:slo_synth_avail:error_budget_remaining_ratio'; do
  require_pattern "$tmp_slo_group" "record:[[:space:]]*${record}[[:space:]]*$" "libreplay.slo missing recording rule ${record}"
done

for alert in LibrePlaySLOErrorBudgetBurnFast LibrePlaySLOErrorBudgetBurnMedium LibrePlaySLOErrorBudgetBurnSlow; do
  require_pattern "$tmp_slo_group" "alert:[[:space:]]*${alert}[[:space:]]*$" "libreplay.slo missing alert ${alert}"
done
require_pattern "$tmp_slo_group" 'probe_success\{job="libreplay-lan-synthetic",app="libreplay",endpoint="health"\}' "libreplay.slo SLI must target the LibrePlay LAN synthetic health probe"
ok "VMRule libreplay.slo group has 6 recording rules and 3 burn-rate alerts"

# --- staging JSON6902 remove patch must delete higher group index first ----
# Descending order is mandatory: removing /spec/groups/1 first would shift
# /spec/groups/2 down and the second op would target the wrong / out-of-range
# group.
require_pattern "$staging_remove_patch" '/spec/groups/2' "staging remove patch must remove /spec/groups/2 (libreplay.slo)"
require_pattern "$staging_remove_patch" '/spec/groups/1' "staging remove patch must remove /spec/groups/1 (libreplay.synthetics)"
g2_line="$(grep -n '/spec/groups/2' "$staging_remove_patch" | head -n1 | cut -d: -f1)"
g1_line="$(grep -n '/spec/groups/1' "$staging_remove_patch" | head -n1 | cut -d: -f1)"
if [ -z "$g2_line" ] || [ -z "$g1_line" ] || [ "$g2_line" -ge "$g1_line" ]; then
  fail "staging remove patch must list /spec/groups/2 BEFORE /spec/groups/1 (descending order)"
fi
ok "staging remove patch removes /spec/groups/2 before /spec/groups/1 (descending order)"

kubectl kustomize "$root/k8s" > "$tmp_base"
kubectl kustomize "$root/staging/overlays/runtime" > "$tmp_staging"

require_pattern "$tmp_base" 'name:[[:space:]]*libreplay-lan-synthetic[[:space:]]*$' "base render must include libreplay-lan-synthetic"
reject_pattern "$tmp_staging" 'libreplay-lan-synthetic' "staging runtime render must not include LAN synthetic probe"
ok "render checks confirm base includes probe and staging excludes it"

require_pattern "$tmp_base" 'name:[[:space:]]*libreplay\.slo[[:space:]]*$' "base render must include libreplay.slo group"
reject_pattern "$tmp_staging" 'name:[[:space:]]*libreplay\.slo[[:space:]]*$' "staging runtime render must not include libreplay.slo group (LAN SLI absent in staging)"
ok "render checks confirm base includes libreplay.slo and staging excludes it"
