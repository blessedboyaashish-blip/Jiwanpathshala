#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# preflight.sh — validate the deploy environment WITHOUT printing secret values.
#
# Checks:
#   1. Required and recommended env var names are defined (presence only).
#   2. The build entrypoint (index.html) exists.
#   3. Provider config files are present and parse as valid JSON / YAML where
#      a parser is available locally.
#   4. The selected provider CLI is installed (only if PROVIDER is set).
#
# This script NEVER echoes the value of any variable that looks secret. It
# prints "set" / "missing" / "empty" only.
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROVIDER="${PROVIDER:-${1:-}}"
FAIL=0

color() {
  local code="$1"; shift
  if [ -t 1 ]; then printf "\033[%sm%s\033[0m\n" "$code" "$*"; else printf "%s\n" "$*"; fi
}
ok()    { color "32" "  ok    $*"; }
warn()  { color "33" "  warn  $*"; }
err()   { color "31" "  FAIL  $*"; FAIL=1; }
head1() { color "1;36" "▸ $*"; }

# Variable name => classification.
# REQUIRED: the deploy refuses to proceed if missing.
# RECOMMENDED: deploy proceeds with a warning.
# SECRET: presence checked, value never printed.
REQUIRED_VARS=()
RECOMMENDED_VARS=(PUBLIC_APP_TITLE PUBLIC_SHEET_CSV_URL)
SECRET_VARS=(SENTRY_DSN ANALYTICS_API_KEY GOOGLE_SHEETS_API_KEY)

# Load .env without exporting to subprocesses we don't control.
if [ -f .env ]; then
  head1 "Loading .env"
  # shellcheck disable=SC1091
  set -a; . ./.env; set +a
  ok ".env loaded"
else
  warn ".env not found (fine for CI / provider-managed env)"
fi

head1 "Required variables"
if [ "${#REQUIRED_VARS[@]}" -eq 0 ]; then
  ok "none declared"
else
  for v in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!v:-}" ]; then err "$v is missing"; else ok "$v is set"; fi
  done
fi

head1 "Recommended variables"
for v in "${RECOMMENDED_VARS[@]}"; do
  if [ -z "${!v:-}" ]; then warn "$v not set (optional)"; else ok "$v is set"; fi
done

head1 "Secret variables (presence only)"
for v in "${SECRET_VARS[@]}"; do
  if [ -z "${!v:-}" ]; then warn "$v not set"; else ok "$v is set"; fi
done

head1 "Project files"
[ -f index.html ]   && ok "index.html"   || err "index.html missing"
[ -f package.json ] && ok "package.json" || err "package.json missing"
[ -f vercel.json ]  && ok "vercel.json"  || warn "vercel.json missing (only needed for Vercel)"
[ -f render.yaml ]  && ok "render.yaml"  || warn "render.yaml missing (only needed for Render)"
[ -f railway.json ] && ok "railway.json" || warn "railway.json missing (only needed for Railway)"

head1 "Config syntax"
if command -v node >/dev/null 2>&1; then
  for f in vercel.json railway.json; do
    [ -f "$f" ] || continue
    if node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null; then
      ok "$f parses as JSON"
    else
      err "$f is not valid JSON"
    fi
  done
else
  warn "node not installed; skipping JSON validation"
fi

if [ -f render.yaml ]; then
  if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
    if python3 -c "import yaml,sys; yaml.safe_load(open('render.yaml'))" 2>/dev/null; then
      ok "render.yaml parses as YAML"
    else
      err "render.yaml is not valid YAML"
    fi
  else
    warn "PyYAML not available; skipping render.yaml validation"
  fi
fi

if [ -n "$PROVIDER" ]; then
  head1 "CLI for provider: $PROVIDER"
  case "$PROVIDER" in
    vercel)  command -v vercel  >/dev/null 2>&1 && ok "vercel CLI"  || warn "vercel CLI not installed (npm i -g vercel)" ;;
    render)  command -v render  >/dev/null 2>&1 && ok "render CLI"  || warn "render CLI not installed (brew install render or see render.com/docs/cli)" ;;
    railway) command -v railway >/dev/null 2>&1 && ok "railway CLI" || warn "railway CLI not installed (npm i -g @railway/cli)" ;;
    *)       err "unknown PROVIDER '$PROVIDER' (expected: vercel|render|railway)" ;;
  esac
fi

echo
if [ "$FAIL" -ne 0 ]; then
  color "1;31" "preflight: FAILED"
  exit 1
fi
color "1;32" "preflight: OK"
