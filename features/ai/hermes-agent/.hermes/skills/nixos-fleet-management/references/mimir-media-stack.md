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
| homarr | docker-homarr (OCI container) | 7575 | `/` → 307 |

Notes:
- readarr logs a harmless `SQLite error (1): near "SHOW": syntax error` at
  startup (its version probe against SQLite). Not a failure signal.
- seerr and jellyseerr BOTH bind 5055 — never enable both simultaneously.
- **homarr** originally shipped as an in-repo systemd module running
  `npm start` from `/data/services/homarr`, which stays empty — crash-loop +
  magic-rollback every deploy, and pinned nixpkgs has neither a `homarr`
  package nor `services.homarr`. Replaced with
  `virtualisation.oci-containers.containers.homarr`
  (`ghcr.io/homarr-labs/homarr`, 7575:7575, data under
  `/data/services/homarr/{data,appdata}`, generated `SECRET_ENCRYPTION_KEY`
  baked into the module). Gotcha: its systemd unit reports `inactive` while
  serving fine — oci-containers hands off to the daemon; verify by HTTP
  probe, not unit state.
- Untested: whisparr, calibre, spotify, vlc.

## Mimir port budget — rootless containers already own ports

Long-running rootless docker stack on mimir (check `docker ps` +
`sudo ss -tlnp` BEFORE assigning any NixOS service a port):
- logto-db (postgres): **5432**
- yb-tserver/yb-master (yugabyte): **5433**, 7000, **9000**, 9042…
- redis: 6379 · rabbitmq: 5672 (mgmt 8082) · jaeger: 16686 · otel-collector:
  4317–4318 · azurite: 10000–10002

This is why NixOS postgresql lives on 5434 — and why **grafana was moved
from 9000 to 3000** (`fix(monitoring): move grafana to port 3000`):
yb-tserver's UI holds host 9000, which left grafana.service silently failed
across many green deploys. Lesson: switch-to-configuration does NOT restart
unchanged units, so "Deployment confirmed" proves nothing about units that
were already broken — sweep `systemctl is-active` for all service units when
taking over a fleet.

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
