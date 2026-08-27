---
id: nixos-fleet-management
name: NixOS Fleet Management
description: >-
  Manage Drakkar/Huginn/Mimir via unified flake + deploy-rs. Prefer
  nixos-deploy-rs and nixos-managing skills. Hermes-specific SSH/wrappers are
  out of scope for the multi-host-deploy-rs mission.
---

# NixOS Fleet Management

**Canonical skills:** `nixos-deploy-rs`, `nixos-managing`

**Mission:** `.maestro/specs/multi-host-deploy-rs.md`

**Mimir media stack:** see `references/mimir-media-stack.md` for the enabled
features table with smoke-check units/ports/probes, mimir's container-owned
port budget (5432 logto-db, 5433 yugabyte — NixOS postgres lives on 5434),
the invidious postgresql hba wiring. Smoke-check pattern (no repo-root verify
script exists as of 2026-08 — the referenced `scripts/verify-media-stack.sh`
survives only inside the off-limits hermes-agent feature copy): per service,
`systemctl is-active <unit>` + `curl -s -o /dev/null -w "%{http_code}"`
against its local port; any code <500 means the app is up.

**Dashboard = homepage-dashboard (since 2026-08-24, commit 8f501e36).**
Homarr was removed ENTIRELY from the repo and fleet after a two-day arc:
native vendored build SIGABRT-looped (better-sqlite3 × Node 24) → OCI-image
revert → declarative board sync pipeline → still not worth the cost → full
removal (postmortem: `nixos-media-service-creation` §4 + §9b). The dashboard
is now `services.homepage-dashboard` (nixpkgs-native, fully declarative Nix:
settings/bookmarks/services/widgets), **port 8083 on mimir** (its historical
8080 now belongs to qbittorrent-nox's WebUI). Homepage v1.x validates the
request Host header against HOMEPAGE_ALLOWED_HOSTS — the nixpkgs module
exposes this as `services.homepage-dashboard.allowedHosts`, whose default
only allows localhost:8082; without `<host>:8083` in it every remote request
gets "Host validation failed" (fixed 2026-08-24, 6368ed9f). When changing
listenPort or hostname, update allowedHosts in the same change.
Dashboard pitfalls (2026-08-24):
- A deploy that only rewrites `/etc/homepage/*.yaml` does NOT restart the
  service — the unit file is unchanged so the switch skips it, and the
  served board stays stale until an explicit
  `systemctl restart homepage-dashboard`.
- Icon URLs rot. Prefer walkxcode/dashboard-icons raw SVGs
  (`https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/<name>.svg`,
  same source as the qBittorrent entry) and curl-check each URL before
  committing; dead sources already hit: prometheus.io asset paths,
  invidious.snopyta.org.
- The Grafana card must point at :3000 (:9000 is yb-tserver UI — see the
  rootless container stack below).

## Do

1. Use root flake `deploy.nodes` + `bin/fleet deploy .#<host>`
2. Keep per-host Disko/hardware under `hosts/<name>/`
3. Disable comin while push-deploy is primary
4. Operator SSH via `~/.ssh/config` — not `~/.hermes/`
5. When planning services, FIRST check `features/media/` and
   `features/monitoring/` for existing fully Nix-managed modules before
   creating new ones
6. Update related runbooks in `docs/runbooks/` when adding new services
7. Verify every change against the evaluated merged config and the live
   host — not just the source files

## Do not

- Install Hermes-only deploy keys or `~/.hermes/bin/nixos-mgmt`
- Activate with Colmena and deploy-rs on the same generation stream
- Invent `colmena rollback` / `colmena update` subcommands
- Expose services to WAN — keep all services Tailscale-only unless absolutely necessary

## Host Roles & Service Assignment

All media and monitoring services already exist as NixOS modules in
`features/media/` and `features/monitoring/` — check existing features before
creating new ones.

| Host | Role |
|------|------|
| Drakkar | Desktop workstation + remote Nix builder; optional media consumption clients |
| Huginn | Tablet/mobile device; minimal profile |
| Mimir | Primary services host: jellyfin, invidious, qbittorrent-nox, jackett/flexget/transmission (native modules, replaced the *arr family 2026-08-25), seerr, prometheus server, grafana; NFS server |

Persistent service data goes in `/data/services/<name>` (NFS-exported so
drakkar/huginn can reach it) — never `/mnt/well`. Mimir's rootless container
stack owns ports 5432 (logto-db), 5433 (yb-tserver) and **9000** (yb-tserver
UI); host-level postgresql uses 5434 and **grafana runs on 3000** (its old
9000 assignment left the unit silently failed across many green deploys —
unchanged units are not restarted by later switches). The rootless stack is
the `monorepo` Docker Compose project (`/data/Code/monorepo/docker-compose.yml`
on mimir: yb-master/yb-tserver, logto-db, rabbitmq, redis, jaeger,
otel-collector, azurite — all `restart: always`, resurrected by boot-enabled
rootless docker). It is NOT managed by this flake; don't look for it in git
history, and never assign its published ports (5432/5433/7000/9000/4317-4318/
55679/5672/8082/10000-10002/14250/14268/9411/16686) to NixOS services.
Prometheus server on 9001 scrapes node exporters fleet-wide via `<host>:9002`
targets in its nodes job. **qbittorrent-nox WebUI owns 8080**; homepage-dashboard runs on
**8083** (restoring it on its historical 8080 caused EADDRINUSE → start-limit-
hit). See `nixos-media-service-creation` before hand-rolling units for apps with
no nixpkgs package. Dashboard/service icons: use raw SVGs from the
walkxcode/dashboard-icons repo
(`https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/<name>.svg`)
— app-bundled icon URLs rot silently (prometheus.io asset 404,
invidious.snopyta.org dead, jellyfin banner-light.png gone from the web bundle;
fixed 2026-08-24, 73b464e5). Verify every icon/href with curl before deploying.

## Service Deployment Planning

### Foundation Analysis
- Review host configs (`hosts/*/configuration.nix`)
- Check existing feature modules first; understand storage/resources per host
- Consult runbooks (`docs/runbooks/*.md`) for deployment patterns

### Implementation Phases
1. Foundation & monitoring (node exporters fleet-wide, grafana on mimir)
2. Storage & media infrastructure (`/data/services/<name>` layout)
3. Service deployment — enable one feature at a time, deploy, smoke-check
   (see `nixos-deploy-rs` → "Enabling features one-by-one")
4. Networking & access (Tailscale-only)
5. Dashboard & integration

### Verification
- `nix flake check` after each module change
- `bin/fleet check <host>` before deploying
- Post-deploy: unit active + local HTTP probe per service (see smoke-check
  pattern at top; no repo-root verify script exists as of 2026-08)

## Fleet audit notes (2026-08)

- **Alerting is effectively dead**: `features/monitoring/prometheus/default.nix`
  ships Alertmanager with a placeholder webhook (127.0.0.1:5001) and
  example.com SMTP — nothing receives alerts. Combined with "unit state lies,
  probe the port", the fleet has no working alert path.
- **No backups anywhere**: no borg/restic/rustic/sanoid in features/, hosts/,
  or profiles/. All persistent state is `/data/services/<name>` on mimir
  (NFS-exported). If adding coverage, prefer rustic (Rust, restic format).
- Secrets hygiene: `features/media/api-keys.nix` carries five live *arr
  API keys committed plaintext. Move to sops-nix/agenix before further edits.
- *arr family decommissioned on mimir (2026-08-25): imports removed from
  `hosts/mimir/configuration.nix`; feature dirs, configs and assays KEPT in
  the repo for revival. Replaced by native-module Jackett (:9117),
  FlexGet (:5050) and Transmission (:9091 RPC / :51413 peer). Two live
  lessons from that cutover: (1) redeploying a long-crash-looped daemon
  without clearing its app-level lock file (`.flexget-lock`) makes
  switch-to-configuration fail and deploy-rs magic-rollback resurrect the
  broken old units — stop, reset-failed, rm the lock, THEN deploy;
  (2) transmission answers 403 Forbidden to hostname-addressed RPC unless
  both rpc whitelists are declared off (the native module's settings merge
  handles it: see `nixos-media-service-creation` → Step 0 +
  `references/native-media-modules.md`).
- Rust-replacement candidates for repo tooling: see the `fleet-rust-tooling`
  skill (`devops/`) and its `references/replacement-candidates.md`.
- Dashboard history (2026-08): homepage-dashboard → homarr (npm-start,
  broken) → homarr vendored native (SIGABRT) → homarr OCI + declarative
  board sync (green but high-maintenance) → **homepage-dashboard again**
  (commit 4b7ea498, port 8083). Lesson encoded in
  `nixos-media-service-creation` §9b: prefer the nixpkgs-native module when
  one exists; when restoring a module from git history, re-check its port
  against TODAY'S fleet before deploying.

**Reference**: see `templates/media-service-deployment-plan.md` for a
complete deployment checklist.
