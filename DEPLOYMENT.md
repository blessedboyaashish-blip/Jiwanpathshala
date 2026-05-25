# Deployment Guide

This repository ships a static frontend (`index.html`) and a build pipeline
that deploys cleanly to **Vercel**, **Render**, or **Railway**. Pick one — the
same `scripts/deploy.sh` drives all three.

> **Note on app name:** the GitHub repo is `Jiwanpathshala`. The task brief
> refers to a *Life Trends* application; this is the only frontend present in
> the repository, so the deployment infrastructure here packages it as-is and
> preserves its current behavior (static page + optional Google Sheet CSV
> sync). No application code was changed.

---

## 1. Quick start

```bash
# 1. Install deps (only the local server uses node; nothing else is required).
npm install

# 2. Copy the env template and edit values you want injected at deploy time.
cp .env.example .env

# 3. Validate without printing any secret values.
npm run preflight

# 4. Pick a provider and ship.
scripts/deploy.sh vercel  --prod
scripts/deploy.sh render  --prod
scripts/deploy.sh railway --prod
```

Run `scripts/deploy.sh` with no `--prod` flag to push a preview / non-production
deployment where the provider supports it (Vercel preview URLs, Railway PR
environments).

---

## 2. Environment variables

The application currently has **no required secrets** — it is a static page
that optionally fetches a public Google Sheet CSV URL the user pastes into the
UI. The variables below are wired up for forward compatibility; set the ones
you actually use.

| Variable                 | Scope          | Purpose                                            |
| ------------------------ | -------------- | -------------------------------------------------- |
| `PORT`                   | Server         | Bind port for Render / Railway. Auto-injected.     |
| `NODE_ENV`               | Server         | Standard Node environment flag.                    |
| `PUBLIC_APP_TITLE`       | Public (front) | Override navbar title.                             |
| `PUBLIC_SHEET_CSV_URL`   | Public (front) | Default published Google Sheet CSV URL.            |
| `SENTRY_DSN`             | Secret         | Reserved for future server-side error reporting.   |
| `ANALYTICS_API_KEY`      | Secret         | Reserved for future analytics integration.         |
| `GOOGLE_SHEETS_API_KEY`  | Secret         | Reserved for private-sheet server proxy support.   |

Anything prefixed `PUBLIC_` is **safe to expose to the browser**. Anything else
must stay server-side.

`scripts/preflight.sh` only reports `set` / `missing` / `empty` for each name
— it never echoes a value, so it's safe to run in CI logs.

---

## 3. Provider-specific setup

### 3a. Vercel

1. Install the CLI and log in:
   ```bash
   npm i -g vercel
   vercel login
   ```
2. Link the project once:
   ```bash
   vercel link
   ```
3. Set environment variables (per environment — `production`, `preview`,
   `development`):
   ```bash
   vercel env add PUBLIC_APP_TITLE      production
   vercel env add PUBLIC_SHEET_CSV_URL  production
   # Repeat for any secret keys you actually need:
   vercel env add SENTRY_DSN            production
   ```
   You can also set them in the dashboard: **Project → Settings →
   Environment Variables**.
4. Deploy:
   ```bash
   scripts/deploy.sh vercel --prod
   ```

`vercel.json` declares `outputDirectory: public`, security headers, and
no-cache for `index.html`.

### 3b. Render

1. Create a free account at <https://render.com>.
2. Either:
   - **Blueprint flow (recommended):** push this repo to GitHub, click
     *New → Blueprint*, point at the repo. Render reads `render.yaml` and
     creates the web service automatically.
   - **CLI flow:**
     ```bash
     brew install render          # or see https://render.com/docs/cli
     render login
     render blueprint launch
     ```
3. Set environment variables:
   - Dashboard: **Service → Environment → Add Environment Variable**.
   - CLI: `render env set PUBLIC_APP_TITLE "Jiwan Pathshala" --service <id>`.
4. Deploy:
   ```bash
   scripts/deploy.sh render --prod
   ```

The Render service runs `npm start`, which serves `./public` from
`scripts/serve.js`. Health checks hit `/healthz`.

### 3c. Railway

1. Install the CLI and authenticate:
   ```bash
   npm i -g @railway/cli
   railway login
   ```
2. Initialize / link the project once:
   ```bash
   railway init        # or: railway link <project-id>
   ```
3. Set environment variables:
   ```bash
   railway variables set PUBLIC_APP_TITLE="Jiwan Pathshala"
   railway variables set PUBLIC_SHEET_CSV_URL="https://docs.google.com/..."
   # secrets:
   railway variables set SENTRY_DSN="<value>"
   ```
   Or use the dashboard: **Project → Variables**.
4. Deploy:
   ```bash
   scripts/deploy.sh railway --prod
   ```

`railway.json` configures the Nixpacks builder and health check.

---

## 4. The deploy script

`scripts/deploy.sh <provider> [--prod] [--skip-preflight]`

Order of operations:

1. `scripts/preflight.sh` — checks env var **names** (never values), validates
   `vercel.json` / `railway.json` parse as JSON and `render.yaml` parses as
   YAML when `python3` + `PyYAML` is available, confirms the provider CLI is
   installed.
2. `npm run build` — copies `index.html` into `./public/`.
3. Provider CLI deploy — `vercel deploy`, `render blueprint launch`, or
   `railway up`.

Skip preflight with `--skip-preflight` if you've already validated. Use
`--prod` for a production deployment.

---

## 5. Local development

```bash
npm install
npm run build
npm start          # serves http://localhost:3000
```

`scripts/serve.js` is a zero-dependency static server with a `/healthz`
endpoint matching the one the platforms probe.

---

## 6. Safety notes

- **No real secrets are committed.** `.env` is gitignored; only `.env.example`
  ships in the repo.
- Preflight prints variable names only — never values.
- `vercel.json` adds `X-Content-Type-Options`, `X-Frame-Options`, and
  `Referrer-Policy` headers by default.
- If you add a new secret, also add its **name** (not value) to
  `SECRET_VARS=(...)` in `scripts/preflight.sh` so future deploys validate it.
