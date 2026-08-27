# Mimir media stack — session detail (enabled 2026-08-22)

Committed in `feat(media): enable media stack on mimir`. Ten features live;
this file records what "healthy" looks like and the traps hit along the way.

## Enabled features & smoke targets

| Feature | Unit | Port | Healthy probe |
|---|---|---|---|
| jellyfin | jellyfin.service | 8096 | `/web/` → 200; `/System/Info/Public` returns JSON |
| lidarr | lidarr.service | 8686 | `/` → 200 |
| sonarr | sonarr.service | 8989 | `/` → 200 |
| radarr | radarr.service | 7878 | `/` → 200 |
| prowlarr | prowlarr.service | 9696 | `/` → 200 |
| qbittorrent | qbittorrent-nox.service | 8080 | `/` → 200 |
| readarr | readarr.service | 8787 | `/` → 200 after ~10 s .NET warm-up |
| seerr | seerr.service | 5055 | `/` → 307 setup redirect (= healthy) |
| invidious | invidious.service + postgresql.service | 4000 | `/` → 302 |
| homepage-dashboard | homepage-dashboard.service | 8083 | `/` → 200 with `Host: mimir:8083` (see SKILL.md dashboard pitfalls) |

Removed from fleet: **homarr** (all homarr* units + redis-homarr) — replaced
by homepage-dashboard 2026-08-24; the homarr rows below are historical.

Notes:
- readarr logs a harmless `SQLite error (1): near "SHOW": syntax error` at
  startup (its version probe against SQLite). Not a failure signal.
- seerr and jellyseerr BOTH bind 5055 — never enable both simultaneously.
- **homarr** runs as NATIVE systemd services built from the vendored
  `pkgs/homarr` package (nixpkgs PR #430235, v1.31.0):
  `homarr.service` (nextjs web, 7575), `homarr-wss` (3001),
  `homarr-tasks` (cron jobs), `homarr-migrate` (oneshot), and dedicated
  `redis-homarr` on 127.0.0.1:6380. Module:
  `features/media/homarr/default.nix`; data under
  `/data/services/homarr/appdata`. History: npm-start variant (empty dir,
  could never work) → OCI container (`docker-homarr`) → native build
  (current). Two failure modes found 2026-08-23, both FIXED by commit
  38c22740 (`fix(media): homarr AUTH_SECRET + rate-limit-safe task
  restarts`):
  - **GitHub rate-limit SIGABRT crash loop** (FIXED/mitigated):
    `homarr-tasks` fetches icon trees from `api.github.com/repos/{
    selfhst/icons, simple-icons/simple-icons,
    homarr-labs/dashboard-icons}/git/trees/*` UNAUTHENTICATED at every
    start. On 403 it dies with `Assertion failed: (env) != nullptr` →
    SIGABRT exit 1; the old 5 s restart loop burned ~2100 req/h against a
    60 req/h shared-IP quota and journal-filled with abort stack traces
    that look like core dumps (`coredumpctl list` stays EMPTY). Mitigation
    now in the module: `RestartSec = 1200` on serviceCommon + hourly
    `homarr-tasks-revive.timer` (armed via ExecStartPost). Quota status:
    `curl -sI https://api.github.com/repos/selfhst/icons`
    (`x-ratelimit-remaining`, epoch `x-ratelimit-reset`). Durable fix
    still pending: inject a token into the unit env or upstream
    degrade-gracefully-on-403.
  - **Missing AUTH_SECRET** (FIXED): authjs `MissingSecret` errors every
    few seconds, tRPC widget crashes, web `/` → **500** while unit active.
    AUTH_SECRET now set in sharedEnv (value plaintext — fold into the
    future sops-nix migration per api-keys.nix hygiene note). Verified
    live post-deploy: `/` → 200, zero MissingSecret in fresh journal.
    homarr-tasks healthy end-state: icons fetch succeeds
    (`Successfully fetched 28447 icons from 6 repositories`), no SIGABRTs.
  - **Root-owned sqlite** (FIXED 2026-08-23, approved): db.sqlite was
    root:root (created by a pre-module root-run migrate); tasks logged
    `SqliteError: attempt to write a readonly database`. Repair:
    `sudo chown -R homarr:data /data/services/homarr/appdata/db`.
    **Trap:** after ANY permission/state repair of persistent data,
    restart EVERY unit that consumes it — the web process kept prepared
    statements bound to the OLD inode and SIGABRTed in
    `better-sqlite3 Statement::~Statement()` →
    `node::RemoveEnvironmentCleanupHook` assertion until all three units
    were restarted cleanly. `chown` alone is never the finish line.
    tmpfiles rules only fix FRESH dirs.
  - **RestartSec=1200 trade-off**: after a failure the web unit dwells in
    `auto-restart` up to 20 min (by design — no quota burn), so recovery
    needs an explicit `systemctl start`, and NRestarts stays deceptively
    low. Don't read the long dwell as a hang.
- Untested: whisparr, calibre, spotify, vlc.

## Mimir port budget — rootless containers already own ports

Long-running rootless docker stack on mimir (check `docker ps` +
`sudo ss -tlnp` BEFORE assigning any NixOS service a port). Origin fully
traced 2026-08-24: it is the Docker Compose project `monorepo` at
`/data/Code/monorepo/docker-compose.yml` — NOT managed by the NixOS config,
NOT in repo history. Every service sets `restart: always` and the rootless
`docker.service` user unit is boot-enabled, so Docker resurrects the whole
stack on every boot. Current members: yb-master + yb-tserver (yugabyte;
tserver UI on **9000**, pgsql proxy on 5433), logto-db (postgres, 5432),
redis 6379, rabbitmq 5672 (mgmt 8082), jaeger 16686, otel-collector
4317–4318, azurite 10000–10002; exited: logto (3001–3002), azurite-init.

This is why NixOS postgresql lives on 5434 — and why **grafana was moved
from 9000 to 3000** (`fix(monitoring): move grafana to port 3000`):
yb-tserver's UI holds host 9000, which left grafana.service silently failed
across many green deploys. Lesson: switch-to-configuration does NOT restart
unchanged units, so "Deployment confirmed" proves nothing about units that
were already broken — sweep `systemctl is-active` for all service units when
taking over a fleet. This trap has TWO faces (both hit by 2026-08-24):
(1) a unit that was already broken stays broken through green deploys
(grafana-on-9000), and (2) a deploy that changes only config files the app
reads at startup (e.g. `/etc/homepage/*.yaml`) leaves the RUNNING process on
the old config until an explicit restart — always smoke-check SERVED
content, not just unit state, after board/config edits.

## Monitoring ports & wiring (current)

- grafana: **3000** (`/api/health` → database ok; datasource = prometheus;
  no `admin_password` option set, so upstream default admin/admin applies
  until changed at first login)
- prometheus server: **9001**; nodes job scrapes mimir local
  (`0.0.0.0:9002`) + `drakkar:9002` + `huginn:9002` (resolve via `.lan`;
  verify via `/api/v1/targets` → health=up). Scrape interval is 1s —
  aggressive, candidate to relax.
- prometheus-node-exporter: **9002** on drakkar, huginn, mimir
  (single owner of exporter config:
  `features/monitoring/prometheus-exporter/`; do not also set
  `services.prometheus.exporters.node` in another imported module — list
  options concatenate across imports and duplicate every collector flag).

## Invidious + postgresql wiring (features/media/invidious/default.nix)

1. `services.postgresql.settings.port = 5434;` — plain
   `services.postgresql.port` is deprecated (rename warning).
2. Upstream `database.createLocally` writes `db.host=""` expecting
   unix-socket **peer auth**, but invidious' crystal-pg client resolves ""
   to **localhost TCP** and sends an empty password → `password
   authentication failed for user "invidious"`. Fix in the module:
   `services.postgresql.authentication` hba rules granting
   `host invidious invidious 127.0.0.1/32 trust` (and ::1) ahead of the
   scram-sha-256 catch-alls, plus `local all all peer`.

## Per-feature enable loop (procedure)

1. Uncomment/add the import in `hosts/mimir/configuration.nix` — each
   import exactly once (NixOS concatenates list options across duplicates).
2. `bin/fleet deploy mimir` (run from the repo root — see the worktree/cwd
   pitfall in nixos-deploy-rs).
3. Smoke check over SSH: `systemctl is-active <unit>` + curl the port;
   200/302/307 all count as up.
4. If deploy-rs rolled back: the new unit crashed — read
   `journalctl -u <unit>` on the target, fix the module, redeploy.
5. Commit at the end with per-feature evidence in the message.

Full automated suite (eval-level + live runtime): `scripts/verify-media-stack.sh`.
