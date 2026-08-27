---
name: idclear-vps-testing-deploy
description: >-
  Deploy idclear to the testing VPS (SSH targ@212.227.30.157, testing.idclear.com)
  via docker compose prod overlay. Use when user asks to deploy, redeploy, push to VPS,
  verify testing.idclear.com, SSH to staging server, or align VPS .env with local parity.
disable-model-invocation: true
---

# idclear VPS testing deploy

## Purpose

Runbook for deploying the idclear monorepo to the **testing VPS** that serves **https://testing.idclear.com**. Covers SSH, git pull, Docker Compose prod rebuild, env parity, verification, and rollback.

## When to use

- User asks to deploy, redeploy, or verify the testing VPS
- Bugfix is on `staging` and needs to go live on testing.idclear.com
- Post-deploy smoke checks or VPS log/DB investigation

## When NOT to use

| Target | Use instead |
|--------|-------------|
| Local dev stack | `devenv shell -- docker compose up -d` — see [idclear-docker-compose-modes](../idclear-docker-compose-modes/SKILL.md) |
| Coolify / testing2 | `docker-compose.coolify.yml` — separate deploy path |
| staging.idclear.com / production | Not this VPS; see infra/terraform and team runbooks |
| Generic deploy theory | [deployment-procedures](../../deployment-procedures/SKILL.md) |

## Environment map

| Item | Value |
|------|-------|
| Host | `212.227.30.157` |
| SSH user | `targ` |
| Repo path | `~/idclear/monorepo` |
| Git branch | `staging` (deployed to testing.idclear.com) |
| Public URL | `https://testing.idclear.com` |
| Compose mode | `COMPOSE_FILE=docker-compose.yml:docker-compose.prod.yml` in server `.env` |

```mermaid
flowchart LR
  devMachine[DevMachine] -->|git push staging| origin[GitHub staging]
  origin -->|ssh git pull| vps[VPS 212.227.30.157]
  vps -->|COMPOSE_FILE prod overlay| compose[docker compose]
  compose --> traefik[Traefik TLS]
  traefik --> site[testing.idclear.com]
```

## Prerequisites

1. Changes are **committed and pushed** to `origin/staging` (see [git-pushing](../../git-pushing/SKILL.md) — only when user requests commit/push).
2. Local verification passed if code changed: `devenv shell -- bun run ci:pre-push:fix` (or project CI equivalent).
3. SSH key access to `targ@212.227.30.157` works (`ssh -o BatchMode=yes targ@212.227.30.157 true`).

All commands below run from the **developer machine**, wrapped with `devenv shell --` per repo shell rules.

## Pre-deploy: VPS `.env` checklist

On the VPS, confirm these **non-secret** keys in `~/idclear/monorepo/.env` (do not commit `.env`):

| Variable | Expected on testing VPS |
|----------|-------------------------|
| `COMPOSE_FILE` | `docker-compose.yml:docker-compose.prod.yml` |
| `IDCLEAR_APP_HOST` | `testing.idclear.com` |
| `NEXT_PUBLIC_VERIDAS_MOCK` | `false` (real Veridas; not local mock default) |

**Build-time vars:** `NEXT_PUBLIC_*` and `IDCLEAR_APP_HOST` are baked into the **test-nextjs** image at build. After changing them on VPS, rebuild `test-nextjs` with `--no-cache`.

Check from dev machine:

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'grep -E "^(COMPOSE_FILE|IDCLEAR_APP_HOST|NEXT_PUBLIC_VERIDAS_MOCK)=" ~/idclear/monorepo/.env'
```

Compare with local (optional parity):

```bash
devenv shell -- bash -c 'grep -E "^(COMPOSE_FILE|IDCLEAR_APP_HOST|NEXT_PUBLIC_VERIDAS_MOCK)=" .env 2>/dev/null || true'
```

## Standard deploy workflow

### 1. Pull latest `staging` on VPS

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && git fetch origin && git checkout staging && git pull origin staging'
```

### 2. Rebuild and restart app services

Full app deploy (typical after portal / worker changes):

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose up --build -d test-nextjs temporal-worker'
```

### 3. Single-service rebuild

When only one service changed:

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose build --no-cache test-nextjs && docker compose up -d test-nextjs'
```

Replace `test-nextjs` with `temporal-worker` as needed.

`docker-compose.prod.yml` selects baked prod targets (`test-nextjs-prod`, etc.) and TLS labels. Details: [idclear-docker-compose-modes](../idclear-docker-compose-modes/SKILL.md).

## Post-deploy verification

### Quick health

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose ps test-nextjs temporal-worker --format "table {{.Name}}\t{{.Status}}"'

devenv shell -- curl -sf https://testing.idclear.com/healthz && echo " OK"
```

### Extended smoke

Use the script in [reference.md](./reference.md#smoke-checks).

### Logs (if unhealthy)

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose logs test-nextjs --tail 100'
```

More commands: [reference.md](./reference.md#logs).

## Rollback

1. On VPS, check out the last known-good commit (get SHA from `git log` before deploy).
2. Rebuild affected services — rollback without rebuild leaves old images running.

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && git checkout <prev-sha> && docker compose up --build -d test-nextjs temporal-worker'
```

Do not use `git reset --hard` or force-push unless the user explicitly requests it. See [deployment-procedures](../../deployment-procedures/SKILL.md) for when to rollback vs fix forward.

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Site up but bug still present | Old image still running | `docker compose build --no-cache <service> && docker compose up -d <service>` |
| `healthz` fails | test-nextjs crash or slow start | Check logs; prod healthcheck allows ~60s start_period |
| Veridas works on VPS but not locally | `NEXT_PUBLIC_VERIDAS_MOCK=true` locally | Set `false` in local `.env` and rebuild, or test on VPS |
| DB query fails with `database "idcl" does not exist` | Wrong DB name | App data is in `test_nextjs_payload` on `yb-pg:5433` — see [reference.md](./reference.md#database) |
| Duplicate My Data rows | UI list across multiple subject_products | DB may be fine; check read-model dedup — not a deploy issue |

## Core rules

1. **Branch:** VPS testing tracks **`staging`**, not `main`.
2. **Shell:** Wrap local commands with `devenv shell --`; SSH runs on the VPS inside quoted remote commands.
3. **Secrets:** Never commit or paste full `.env`, Logto passwords, or API keys into skills or chat.
4. **Rebuild after env:** Changing `NEXT_PUBLIC_*` or `IDCLEAR_APP_HOST` requires image rebuild.
5. **Verify:** Always hit `https://testing.idclear.com/healthz` and `docker compose ps` after deploy.

## See also

- [reference.md](./reference.md) — smoke curls, logs, DB psql
- [idclear-docker-compose-modes](../idclear-docker-compose-modes/SKILL.md) — dev vs prod compose overlay
- [history/2026-07-06T09-12-29-docker-dev-prod-mode.md](../../../history/2026-07-06T09-12-29-docker-dev-prod-mode.md) — compose file theory
- [git-pushing](../../git-pushing/SKILL.md) — commit and push before deploy
- [deployment-procedures](../../deployment-procedures/SKILL.md) — rollback principles
