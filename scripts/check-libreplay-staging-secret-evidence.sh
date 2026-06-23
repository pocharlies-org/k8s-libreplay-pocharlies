#!/usr/bin/env bash
# Requires Bash: this script uses `set -o pipefail` and Bash-only constructs
# (`[[ ... ]]`, `${!var}`). Guard against POSIX `sh`/dash so an accidental
# `sh scripts/check-libreplay-staging-secret-evidence.sh` exits with a clear
# message instead of `set: Illegal option -o pipefail` noise. The guard itself
# is POSIX-compatible so dash reaches it before the pipefail line.
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'FAIL: this script requires bash. Run `bash %s [args]` or execute the script path directly; do not run it with `sh`.\n' "$0" >&2
  exit 2
fi

set -euo pipefail

mode="report"
scope="all"

expected_google_callback="https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback"
expected_facebook_callback="https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback"
expected_mail_from="LibrePlay <noreply@libreplay.e-dani.com>"

failures=0
blockers=0

usage() {
  cat <<'EOF'
Usage:
  scripts/check-libreplay-staging-secret-evidence.sh [--strict] [--all]
  scripts/check-libreplay-staging-secret-evidence.sh [--strict] --vault-write

Validates non-secret evidence required before LibrePlay staging real-auth work.
It never prints provider secrets, mailbox values or SMTP credentials.

Required for Vault write:
  LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED=1
  LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/google/callback
  LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI=https://libreplay-staging.e-dani.com/api/auth/oauth/facebook/callback
  LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED=1
  LIBREPLAY_STAGING_SMTP_MAIL_FROM='LibrePlay <noreply@libreplay.e-dani.com>'

Required for the full staging auth gate:
  LIBREPLAY_STAGING_AUTH_EMAIL=<controlled plus-addressable mailbox>
  LIBREPLAY_STAGING_AUTH_EMAIL_PLUS_CONFIRMED=1
EOF
}

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

finish() {
  if [ "$failures" -gt 0 ]; then
    printf 'FAIL: staging secret evidence check found %s failure(s) and %s blocker(s)\n' \
      "$failures" "$blockers" >&2
    exit 1
  fi

  if [ "$blockers" -gt 0 ]; then
    printf 'BLOCKED: staging secret evidence check found %s blocker(s)\n' "$blockers" >&2
    if [ "$mode" = "strict" ]; then
      exit 1
    fi
    exit 0
  fi

  ok "staging secret evidence check complete"
}

is_placeholder() {
  [[ "$1" =~ (TODO|todo|PLACEHOLDER|placeholder|CHANGEME|changeme|example\.com|localhost|\.local) ]]
}

require_flag() {
  var_name="$1"
  description="$2"
  value="${!var_name:-}"

  if [ -z "$value" ]; then
    block "${description} is missing (${var_name})"
    return
  fi

  if [ "$value" = "1" ]; then
    ok "${description} acknowledged"
  else
    fail "${var_name} must be 1 when evidence is approved"
  fi
}

require_exact() {
  var_name="$1"
  expected="$2"
  description="$3"
  value="${!var_name:-}"

  if [ -z "$value" ]; then
    block "${description} is missing (${var_name})"
    return
  fi

  if [ "$value" = "$expected" ]; then
    ok "${description} matches expected LibrePlay staging value"
  else
    fail "${description} does not match the required LibrePlay staging value"
  fi
}

check_mailbox() {
  email="${LIBREPLAY_STAGING_AUTH_EMAIL:-}"

  if [ -z "$email" ]; then
    block "controlled staging mailbox is missing (LIBREPLAY_STAGING_AUTH_EMAIL)"
  elif is_placeholder "$email"; then
    fail "controlled staging mailbox looks like a placeholder or local address"
  elif [[ ! "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    fail "controlled staging mailbox must look like an email address"
  else
    ok "controlled staging mailbox shape is valid; value was not printed"
  fi

  require_flag \
    LIBREPLAY_STAGING_AUTH_EMAIL_PLUS_CONFIRMED \
    "plus-addressing or catch-all delivery for the staging mailbox"
}

for arg in "$@"; do
  case "$arg" in
    --strict) mode="strict" ;;
    --all) scope="all" ;;
    --vault-write) scope="vault-write" ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'FAIL: unknown argument: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$-" == *x* ]]; then
  printf 'FAIL: refusing to run with shell tracing enabled; it could leak evidence context\n' >&2
  exit 2
fi

require_flag \
  LIBREPLAY_STAGING_PROVIDER_CALLBACKS_CONFIRMED \
  "Google and Meta callback evidence"
require_exact \
  LIBREPLAY_STAGING_GOOGLE_CALLBACK_URI \
  "$expected_google_callback" \
  "Google OAuth redirect URI evidence"
require_exact \
  LIBREPLAY_STAGING_FACEBOOK_CALLBACK_URI \
  "$expected_facebook_callback" \
  "Facebook OAuth redirect URI evidence"
require_flag \
  LIBREPLAY_STAGING_SMTP_SENDER_CONFIRMED \
  "SMTP sender/domain evidence"
require_exact \
  LIBREPLAY_STAGING_SMTP_MAIL_FROM \
  "$expected_mail_from" \
  "SMTP sender identity evidence"

if [ "$scope" = "all" ]; then
  check_mailbox
else
  ok "mailbox evidence check skipped for Vault-write scope"
fi

finish
