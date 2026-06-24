#!/usr/bin/env sh
# PROD-OBS-ALERT-SLO-05: read-only LibrePlay alert routing rehearsal.
#
# This checker is strictly READ-ONLY. It asserts, for each LibrePlay SLO/alert
# label-set, which Alertmanager receiver the LIVE shared Alertmanager config
# would route to, using ONLY `amtool config routes test`. It never fires an
# alert, never mutates Alertmanager state, never dumps the Alertmanager config
# and never prints a secret value -- `config routes test` emits only the
# resolved receiver NAME (e.g. monitoring-synapse-webhook-synapse-alertmanager),
# which carries no webhook URL/token.
#
# Hard rules (do NOT relax):
#   * ONLY `/bin/amtool config routes test --config.file=<file> <labels...>`.
#   * NEVER dump the Alertmanager configuration (no config-dump subcommand, no
#     cat/grep of the Alertmanager YAML, no receiver block printed).
#   * NEVER inject or silence alerts, NEVER mutate Alertmanager state,
#     NEVER read or echo a secret value.
#
# A label-set that resolves to a *blackhole* receiver is a FAILURE: the existing
# shared default route blackholes `severity: warning`, and a LibrePlay alert
# that resolves to blackhole is silently dropped (looks configured, never
# notifies). The dedicated-receiver migration is a gated cross-tenant follow-up;
# today the expected non-blackhole receiver is the SHARED Synapse Alertmanager
# receiver -- this checker accepts ANY non-blackhole receiver and reports it,
# without hardcoding that a dedicated LibrePlay receiver exists.
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
contract_checker="$root/scripts/check-libreplay-synthetics-contract.sh"

namespace="${AM_NAMESPACE:-monitoring}"
am_pod="${AM_POD:-vmalertmanager-vm-victoria-metrics-k8s-stack-0}"
am_container="${AM_CONTAINER:-alertmanager}"
am_config="${AM_CONFIG:-/etc/alertmanager/config/alertmanager.yaml}"
am_selector="${AM_SELECTOR:-app.kubernetes.io/name=vmalertmanager}"

# Keep the read-only / no-secret-leak guarantee honest: refuse to run with shell
# tracing on (would echo kubectl/amtool arguments and output).
case "$-" in
  *x*) printf 'FAIL: refusing to run with shell tracing enabled\n' >&2; exit 2 ;;
esac

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

info() {
  printf 'INFO: %s\n' "$*"
}

block() {
  printf 'BLOCKED: %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# 1. The synthetics + SLO contract must pass FIRST (no point rehearsing routing
#    of a malformed/blackholed rule set).
# ---------------------------------------------------------------------------
[ -x "$contract_checker" ] || fail "contract checker not found or not executable: $contract_checker"
contract_out="$(mktemp)"
if "$contract_checker" >"$contract_out" 2>&1; then
  ok "synthetics/SLO contract checker passed (scripts/check-libreplay-synthetics-contract.sh)"
  rm -f "$contract_out"
else
  fail_out="$(sed 's/^/    contract| /' "$contract_out")"
  rm -f "$contract_out"
  printf '%s\n' "$fail_out" >&2
  fail "synthetics/SLO contract checker FAILED; fix the contract before rehearsing routing"
fi

# ---------------------------------------------------------------------------
# 2. Live cluster + Alertmanager pod. Degrade to BLOCKED (exit 0) when the
#    cluster is unreachable -- routing cannot be verified offline, but a
#    connectivity gap is not a routing regression. The blackhole assertion
#    below is a HARD failure when it can run.
# ---------------------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  block "kubectl not found in PATH; routing rehearsal NOT verified (run where the cluster is reachable)"
  exit 2
fi
if ! kubectl --request-timeout=15s get namespace "$namespace" >/dev/null 2>&1; then
  block "cannot reach cluster/namespace ${namespace}; routing rehearsal NOT verified (connectivity)"
  exit 2
fi

# Discover the vmalertmanager pod; fall back to the known stable name.
discovered="$(kubectl --request-timeout=15s -n "$namespace" get pods \
  -l "$am_selector" -o name 2>/dev/null | head -n1 | sed 's@^pod/@@')"
if [ -n "$discovered" ]; then
  am_pod="$discovered"
fi
if ! kubectl --request-timeout=15s -n "$namespace" get pod "$am_pod" >/dev/null 2>&1; then
  block "alertmanager pod ${am_pod} not found in ${namespace}; routing rehearsal NOT verified"
  exit 2
fi
info "rehearsing routes against pod ${am_pod} (container ${am_container}, config ${am_config})"

# ---------------------------------------------------------------------------
# 3. Read-only route rehearsal. For each label-set, resolve the receiver and
#    fail on any blackhole / unresolved result.
# ---------------------------------------------------------------------------
routing_failures=0

route_test() {
  desc="$1"
  shift
  if ! out="$(kubectl --request-timeout=30s -n "$namespace" exec "$am_pod" -c "$am_container" -- \
      /bin/amtool config routes test --config.file="$am_config" "$@" 2>&1)"; then
    routing_failures=$((routing_failures + 1))
    printf 'FAIL: %s -> amtool routes test errored\n' "$desc" >&2
    printf '%s\n' "$out" | sed 's/^/    amtool| /' >&2
    return 0
  fi
  receivers="$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tr '\n' ',' | sed 's/,$//')"
  if printf '%s\n' "$out" | grep -qi 'blackhole'; then
    routing_failures=$((routing_failures + 1))
    printf 'FAIL: %s -> %s (BLACKHOLED / silently dropped)\n' "$desc" "${receivers:-<none>}" >&2
  elif [ -z "$receivers" ]; then
    routing_failures=$((routing_failures + 1))
    printf 'FAIL: %s -> <no receiver resolved>\n' "$desc" >&2
  else
    ok "${desc} -> ${receivers}"
  fi
}

route_test "LibrePlaySyntheticAvailabilityBudgetLow (warn)" \
  alertname=LibrePlaySyntheticAvailabilityBudgetLow app=libreplay area=slo severity=warn
route_test "LibrePlaySLOErrorBudgetBurnFast (critical)" \
  alertname=LibrePlaySLOErrorBudgetBurnFast app=libreplay area=slo severity=critical slo=synthetic-availability burnrate=fast
route_test "LibrePlaySLOErrorBudgetBurnMedium (critical)" \
  alertname=LibrePlaySLOErrorBudgetBurnMedium app=libreplay area=slo severity=critical slo=synthetic-availability burnrate=medium
route_test "LibrePlaySLOErrorBudgetBurnSlow (warn)" \
  alertname=LibrePlaySLOErrorBudgetBurnSlow app=libreplay area=slo severity=warn slo=synthetic-availability burnrate=slow

# ---------------------------------------------------------------------------
# 4. Verdict.
# ---------------------------------------------------------------------------
if [ "$routing_failures" -gt 0 ]; then
  fail "${routing_failures} LibrePlay alert label-set(s) blackholed/unresolved (see above)"
fi
info "all resolved receivers are non-blackhole; today this is the SHARED Synapse receiver (visibility, not a dedicated LibrePlay pager)"
ok "LibrePlay alert routing rehearsal passed: no blackhole, all label-sets resolve to a deliverable receiver"
