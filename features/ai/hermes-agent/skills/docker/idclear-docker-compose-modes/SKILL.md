---
name: idclear-docker-compose-modes
description: >-
  idclear monorepo Docker Compose dev vs production modes for test-nextjs,
  ng-client, and risk-calculator. Covers local dev servers (HMR), comment-toggle
  prod-local image for test-nextjs, and COMPOSE_FILE prod overlay for VPS.
  Use when changing docker-compose.yml app services, debugging container dev
  servers, or switching test-nextjs between dev and baked prod locally.
disable-model-invocation: true
---

# idclear Docker Compose modes

## When to use

- Editing `docker-compose.yml` / `docker-compose.prod.yml` app services
- Running the full stack locally with HMR through Traefik
- Testing a baked test-nextjs image locally without the VPS prod overlay
- Debugging "works on host `bun run dev` but not in Docker"

## Layout

| File | Role |
|------|------|
| `docker-compose.yml` | Local default — dev servers, bind mounts |
| `docker-compose.prod.yml` | VPS overlay — baked images, TLS, no mounts |
| `Dockerfile` | `test-nextjs` (dev), `test-nextjs-prod`, `ng-client`, `ng-client-prod` |
| `history/docker-dev-prod-mode.md` | Human-oriented reference |

## Local stack (default)

```bash
devenv shell -- docker compose up -d
```

| Service | Image target | Runtime |
|---------|--------------|---------|
| test-nextjs | `test-nextjs` | `bun run dev:docker` (webpack + poll) |
| ng-client | `ng-client` | Rspack dev + HMR |
| risk-calculator | dev target | `bun run dev` |

Requires `DOCKER_UID` / `DOCKER_GID` in the shell (devenv `enterShell` + `.envrc`; run `sync-docker-compose-user-env` to refresh). Run `docker compose` from a direnv/devenv shell.

## test-nextjs: dev ↔ local prod toggle

Edit the `test-nextjs` service in `docker-compose.yml`:

1. Comment one `!!merge <<:` line, uncomment the other on the `test-nextjs` service:
   - `!!merge <<: [*idclear-test-nextjs-dev, *env-file-dev, *idclear-extra-hosts, *idclear-run-as-host-user]`
   - `!!merge <<: [*idclear-test-nextjs-prod-local, *env-file, *idclear-extra-hosts]`
2. `devenv shell -- docker compose up -d --build test-nextjs`

### Dev mounts (do not drop)

- `./apps/test-nextjs` — app source
- `./libs` — workspace packages (HMR for shared libs)
- `test-nextjs-node-modules` named volume — preserves image `node_modules`
- tmpfs on `.next` — ephemeral compile output

### Next.js Docker dev invariants

- Use `dev:docker` (`next dev --webpack`), not Turbopack, in containers
- `WATCHPACK_POLLING=true` + webpack `watchOptions.poll` in `next.config.ts`
- `allowedDevOrigins` must include `IDCLEAR_APP_HOST` and `IDCLEAR_TEST_NEXTJS_HOST`
- Traefik already routes `/_next` and `/__nextjs` on the shared app host

## VPS production

In server `.env`:

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.prod.yml
```

```bash
devenv shell -- docker compose up --build -d test-nextjs ng-client risk-calculator
```

`docker-compose.prod.yml` forces `test-nextjs-prod`, strips bind mounts, adds Let's Encrypt labels.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dev server rejects Traefik host | Missing `allowedDevOrigins` | Add hosts in `next.config.ts` |
| No HMR / stale files in Docker | Turbopack or no poll | Use `dev:docker` + `WATCHPACK_POLLING` |
| EACCES on bind mount | Wrong container user | Dev mode needs `*idclear-run-as-host-user` |
| `node_modules` missing after mount | Host tree overwrote image | Keep `test-nextjs-node-modules` volume |
| Prod image missing env | Skipped init volume | Keep `idclear-env-development` mount |

## See also

- `history/docker-dev-prod-mode.md`
- `history/traefik-local-routing.md`
- `.cursor/skills/docker/docker-impl-compose-workflows/SKILL.md`
