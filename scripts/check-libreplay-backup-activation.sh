#!/usr/bin/env sh
# PROD-DR-BACKUP-02 Phase C: read-only live activation checker.
#
# This script verifies the manual backup-credential bootstrap WITHOUT making any
# change and WITHOUT printing secret values. It defaults to "report" mode (exit 0
# while the bootstrap is still pending) and supports `--strict` (non-zero exit
# while any blocker remains). It is intentionally read-only: it never applies,
# patches, creates, deletes or restarts a Kubernetes resource, never touches
# Vault, and never echoes a secret value — only resource names, statuses and the
# set of REQUIRED key NAMES.
#
# It is the gate that must report green BEFORE any backup CronJob or restore
# rehearsal is added. See ops/libreplay-backup/README.md and
# ops/libreplay-backup/activation-evidence-template.md for the manual evidence
# that Security/PMO must sign off in addition to this automated check.
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

namespace="${NAMESPACE:-libreplay}"
argo_namespace="${ARGO_NAMESPACE:-argocd}"
argo_app="${ARGO_APP:-libreplay}"
external_secret="${BACKUP_EXTERNALSECRET:-libreplay-backup-secrets}"
secret_name="${BACKUP_SECRET:-libreplay-backup-secrets}"
contract_checker="$root/scripts/check-libreplay-backup-contract.sh"

# Required Secret key NAMES only. Values are never read or printed.
required_keys="MINIO_BACKUP_ACCESS_KEY MINIO_BACKUP_SECRET_KEY PG_BACKUP_USER PG_BACKUP_PASSWORD"

mode="report"

usage() {
  cat <<'EOF'
Usage:
  scripts/check-libreplay-backup-activation.sh [--strict]

Read-only live activation checker for the LibrePlay backup credential bootstrap
(PROD-DR-BACKUP-02 Phase C). It never mutates cluster/Vault state and never
prints secret values.

Modes:
  (default)   report mode: prints OK/BLOCKED/FAIL and exits 0 while only
              blockers (pending manual bootstrap) remain; exits 1 on hard
              failures (policy/contract violations).
  --strict    treat any remaining blocker as a non-zero exit.

Environment overrides:
  NAMESPACE          target namespace (default: libreplay)
  ARGO_NAMESPACE     Argo CD namespace (default: argocd)
  ARGO_APP           Argo CD Application name (default: libreplay)
  BACKUP_EXTERNALSECRET  ExternalSecret name (default: libreplay-backup-secrets)
  BACKUP_SECRET          Secret name (default: libreplay-backup-secrets)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --strict) mode="strict" ;;
    report|--report) mode="report" ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'FAIL: unknown argument: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

# Refuse to run with shell tracing on: keeps the read-only guarantee honest by
# never tracing kubectl arguments/output, even though no value is requested.
case "$-" in
  *x*) printf 'FAIL: refusing to run with shell tracing enabled\n' >&2; exit 2 ;;
esac

failures=0
blockers=0

ok() {
  printf 'OK: %s\n' "$*"
}

info() {
  printf 'INFO: %s\n' "$*"
}

block() {
  blockers=$((blockers + 1))
  printf 'BLOCKED: %s\n' "$*" >&2
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# 1. Static contract must pass first (asserts the dormant contract is correct
#    and that the backup directory is NOT wired into the Argo-synced
#    kustomization). This is a hard failure if it breaks.
# ---------------------------------------------------------------------------
if [ ! -x "$contract_checker" ]; then
  fail "static contract checker not found or not executable: $contract_checker"
else
  contract_out="$(mktemp)"
  if "$contract_checker" >"$contract_out" 2>&1; then
    ok "static backup contract checker passed (scripts/check-libreplay-backup-contract.sh)"
  else
    fail "static backup contract checker FAILED; see output below"
    sed 's/^/    contract| /' "$contract_out" >&2
  fi
  rm -f "$contract_out"
fi

# ---------------------------------------------------------------------------
# 2. Live cluster state. Everything below is read-only and degrades to a
#    BLOCKED (not a hard failure) when kubectl or the cluster is unavailable.
# ---------------------------------------------------------------------------
kube_ready=0
if ! command -v kubectl >/dev/null 2>&1; then
  block "kubectl not found in PATH; live activation state was not verified"
elif ! kubectl --request-timeout=15s get namespace "$namespace" >/dev/null 2>&1; then
  block "cannot reach cluster or namespace ${namespace}; live activation state was not verified"
else
  kube_ready=1
  ok "namespace ${namespace} is reachable"
fi

# Always restate the required key names (names only, never values).
info "required backup Secret key names: ${required_keys}"

if [ "$kube_ready" -eq 1 ]; then
  # --- 2a. Argo CD Application (informational; reported "if available") ------
  if kubectl --request-timeout=15s -n "$argo_namespace" get application "$argo_app" >/dev/null 2>&1; then
    argo_status="$(kubectl --request-timeout=15s -n "$argo_namespace" get application "$argo_app" \
      -o 'jsonpath={.status.sync.status}|{.status.health.status}|{.spec.source.path}' 2>/dev/null || true)"
    info "Argo app ${argo_app}: ${argo_status:-<unreadable>} (backup contract stays outside the synced path)"
  else
    info "Argo app ${argo_app} not found in ${argo_namespace}; Argo status skipped"
  fi

  # --- 2b. ExternalSecret/libreplay-backup-secrets --------------------------
  if kubectl --request-timeout=15s -n "$namespace" get externalsecret "$external_secret" >/dev/null 2>&1; then
    es_condition="$(kubectl --request-timeout=15s -n "$namespace" get externalsecret "$external_secret" \
      -o 'jsonpath={range .status.conditions[*]}{.type}|{.status}|{.reason}{end}' 2>/dev/null || true)"
    case "$es_condition" in
      *Ready\|True*)
        ok "ExternalSecret ${external_secret} is Ready=True"
        ;;
      *)
        block "ExternalSecret ${external_secret} is not Ready yet (status: ${es_condition:-<no condition>}); manual Vault bootstrap pending"
        ;;
    esac
  else
    block "ExternalSecret ${external_secret} does not exist in ${namespace}; manual bootstrap not started"
  fi

  # --- 2c. Secret/libreplay-backup-secrets + required key NAMES -------------
  if kubectl --request-timeout=15s -n "$namespace" get secret "$secret_name" >/dev/null 2>&1; then
    keyfile="$(mktemp)"
    kubectl --request-timeout=15s -n "$namespace" get secret "$secret_name" \
      -o go-template='{{range $k, $_ := .data}}{{printf "%s\n" $k}}{{end}}' 2>/dev/null \
      | sort > "$keyfile" || true
    missing=0
    for key in $required_keys; do
      if grep -Fxq "$key" "$keyfile"; then
        ok "Secret ${secret_name} contains key ${key}"
      else
        missing=$((missing + 1))
        block "Secret ${secret_name} is missing required key ${key}"
      fi
    done
    if [ "$missing" -eq 0 ]; then
      ok "Secret ${secret_name} materialized all required backup keys (names only verified)"
    fi
    rm -f "$keyfile"
  else
    block "Secret ${secret_name} is not materialized in ${namespace}; ExternalSecret has not synced credentials"
  fi

  # --- 2d. No backup CronJobs may exist before this gate + PMO signoff ------
  cron_names="$(kubectl --request-timeout=15s -n "$namespace" get cronjob -o name 2>/dev/null \
    | grep -Ei 'backup' || true)"
  if [ -z "$cron_names" ]; then
    ok "no backup CronJobs are active in ${namespace} yet (expected before activation signoff)"
  else
    fail "backup CronJob(s) present before activation signoff; remove or document PMO signoff evidence"
    printf '%s\n' "$cron_names" | while IFS= read -r cj; do
      [ -n "$cj" ] && printf '    cronjob present| %s\n' "$cj" >&2
    done
  fi
fi

# ---------------------------------------------------------------------------
# 3. Verdict and exit code.
# ---------------------------------------------------------------------------
if [ "$failures" -gt 0 ]; then
  printf 'FAIL: backup activation check found %s hard failure(s) and %s blocker(s)\n' \
    "$failures" "$blockers" >&2
  exit 1
fi

if [ "$blockers" -gt 0 ]; then
  printf 'BLOCKED: backup activation is not complete: %s blocker(s) remain (manual bootstrap pending)\n' \
    "$blockers" >&2
  if [ "$mode" = "strict" ]; then
    exit 1
  fi
  exit 0
fi

ok "backup activation check complete: ExternalSecret Ready and Secret has all required keys; no premature CronJobs"
