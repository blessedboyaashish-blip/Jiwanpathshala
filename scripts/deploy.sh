#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# deploy.sh — one entrypoint for Vercel, Render, and Railway deployments.
#
# Usage:
#   scripts/deploy.sh <provider> [--prod] [--skip-preflight]
#
# Providers: vercel | render | railway
#
# Behavior:
#   - Runs scripts/preflight.sh first (skip with --skip-preflight).
#   - Runs `npm run build` to produce ./public.
#   - Invokes the provider CLI to deploy.
#   - Never prints secret env var values.
#
# Auth (do BEFORE running):
#   vercel login            # https://vercel.com/cli
#   render login            # or set RENDER_API_KEY
#   railway login           # or set RAILWAY_TOKEN
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

case "${1:-}" in
  -h|--help|"")
    if [ -z "${1:-}" ]; then
      echo "Usage: scripts/deploy.sh <vercel|render|railway> [--prod] [--skip-preflight]" >&2
      exit 2
    fi
    sed -n '2,20p' "$0"
    exit 0
    ;;
esac

PROVIDER="$1"
shift

PROD=0
SKIP_PREFLIGHT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prod|--production) PROD=1 ;;
    --skip-preflight)    SKIP_PREFLIGHT=1 ;;
    -h|--help)           sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

color() {
  local code="$1"; shift
  if [ -t 1 ]; then printf "\033[%sm%s\033[0m\n" "$code" "$*"; else printf "%s\n" "$*"; fi
}
step() { color "1;36" "==> $*"; }
fail() { color "1;31" "ERR  $*"; exit 1; }

if [ "$SKIP_PREFLIGHT" -eq 0 ]; then
  step "Running preflight checks"
  PROVIDER="$PROVIDER" bash scripts/preflight.sh
fi

step "Building static output (./public)"
npm run build

case "$PROVIDER" in
  vercel)
    command -v vercel >/dev/null 2>&1 || fail "vercel CLI not installed. Run: npm i -g vercel"
    step "Deploying to Vercel"
    if [ "$PROD" -eq 1 ]; then
      vercel deploy --prod --yes
    else
      vercel deploy --yes
    fi
    ;;

  render)
    if command -v render >/dev/null 2>&1; then
      step "Deploying to Render via CLI"
      # Render's blueprint deploys from render.yaml. The `render blueprint launch`
      # command creates/updates services from the file in the current repo.
      if [ "$PROD" -eq 1 ]; then
        render blueprint launch --confirm
      else
        render blueprint launch
      fi
    else
      step "Render CLI not found — falling back to git-push deploy"
      cat <<'EOF'
Render auto-deploys from your connected git repository. To deploy:

  1) Push this branch to the repository connected to your Render service.
       git add -A && git commit -m "deploy" && git push
  2) Render will detect render.yaml and (re)build automatically.
  3) Set environment variables in the Render dashboard:
       Service → Environment → Add Environment Variable
     OR via CLI once installed:
       render env set PUBLIC_APP_TITLE "Jiwan Pathshala" --service <service-id>

Install the CLI for one-shot deploys:
  brew install render        # macOS
  # or see https://render.com/docs/cli
EOF
    fi
    ;;

  railway)
    command -v railway >/dev/null 2>&1 || fail "railway CLI not installed. Run: npm i -g @railway/cli"
    step "Deploying to Railway"
    # `railway up` packages the current directory and deploys it. The service
    # must already be linked: run `railway link` once, or set RAILWAY_TOKEN.
    if [ "$PROD" -eq 1 ]; then
      railway up --detach
    else
      railway up --detach
    fi
    ;;

  *)
    fail "unknown provider: $PROVIDER (expected: vercel | render | railway)"
    ;;
esac

color "1;32" "deploy: done"
