#!/usr/bin/env sh
set -eu

mode="${1:---static}"
manifest="${MANIFEST:-k8s/manifest.yaml}"
namespace="${NAMESPACE:-libreplay}"
job_name="${JOB_NAME:-libreplay-minio-policy-20260621}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'OK: %s\n' "$*"
}

render_manifest() {
  kubectl kustomize k8s
}

check_render() {
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' EXIT
  render_manifest > "$rendered"

  grep -Eq "name:[[:space:]]*${job_name}[[:space:]]*$" "$rendered" \
    || fail "media storage policy Job ${job_name} is missing"
  grep -Eq 'mc version enable "\$\{target\}"' "$rendered" \
    || fail "media storage policy must enable bucket versioning"
  grep -Eq -- '--noncurrent-expire-days "\$\{MINIO_NONCURRENT_EXPIRE_DAYS\}"' "$rendered" \
    || fail "media storage policy must expire noncurrent object versions"
  grep -Eq -- '--noncurrent-expire-newer "\$\{MINIO_NONCURRENT_RETAIN_NEWER\}"' "$rendered" \
    || fail "media storage policy must keep a bounded number of newer noncurrent versions"
  grep -Eq -- '--expire-delete-marker' "$rendered" \
    || fail "media storage policy must expire delete markers"
  grep -Eq 'libreplay-minio-policy: lifecycle ensured' "$rendered" \
    || fail "media storage policy must emit auditable lifecycle marker"
  if grep -Eq -- '--expire-days[[:space:]]+"?[0-9]+' "$rendered"; then
    fail "media storage policy must not expire current active media objects by age in this gate"
  fi
  info "static media storage policy render contains conservative versioning/lifecycle controls"
}

check_staging_runtime_render() {
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' EXIT
  kubectl kustomize staging/overlays/runtime > "$rendered"
  grep -Eq "name:[[:space:]]*${job_name}[[:space:]]*$" "$rendered" \
    || fail "staging runtime render is missing media storage policy Job ${job_name}"
  grep -Eq "namespace:[[:space:]]*libreplay-staging[[:space:]]*$" "$rendered" \
    || fail "staging runtime media policy Job must render into libreplay-staging"
  grep -Eq 'MINIO_BUCKET:[[:space:]]*libreplay-media-staging' "$rendered" \
    || fail "staging runtime media policy must target the staging media bucket"
  info "staging runtime render inherits media storage policy for libreplay-media-staging"
}

check_live() {
  succeeded="$(kubectl -n "$namespace" get job "$job_name" -o 'jsonpath={.status.succeeded}' 2>/dev/null || true)"
  [ "$succeeded" = "1" ] || fail "Job ${namespace}/${job_name} has not succeeded"

  logs="$(kubectl -n "$namespace" logs "job/${job_name}" 2>/dev/null || true)"
  printf '%s' "$logs" | grep -F 'libreplay-minio-policy: versioning ensured' >/dev/null \
    || fail "live media policy logs do not show versioning marker"
  printf '%s' "$logs" | grep -F 'libreplay-minio-policy: lifecycle ensured noncurrent_expire_days=30 noncurrent_retain_newer=2' >/dev/null \
    || fail "live media policy logs do not show expected lifecycle marker"
  info "live media storage policy Job succeeded and emitted expected audit markers"
}

case "$mode" in
  --static)
    kubectl apply --dry-run=client -f "$manifest" >/dev/null
    check_render
    check_staging_runtime_render
    ;;
  --live)
    check_live
    ;;
  *)
    fail "usage: $0 [--static|--live]"
    ;;
esac
