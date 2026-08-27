---
name: nixos-media-service-creation
description: Create proper NixOS service modules for media applications following Industrial NixOS dotfiles patterns.
---

# NixOS Media Service Creation Skill

## Overview
This skill covers creating proper NixOS service modules for media applications (Jellyfin, *arr suites, etc.) following established patterns in the Industrial NixOS dotfiles repository. Services are designed to be NFS-compatible and fully managed by NixOS without external state files.

## Prerequisites
- Familiarity with NixOS module system
- Understanding of the repository's feature structure (`features/media/`)
- Knowledge of how services are deployed via fleet/deploy-rs

## Step-by-Step Guide

### 0. Check for a native NixOS module FIRST (we are on NixOS)

Before hand-rolling a unit from the template below, check whether nixpkgs
ships a module: `services.jackett`, `services.transmission`,
`services.flexget`, `services.flood`, ... live in
`nixos/modules/services/torrent/` and `/misc/`. The user's standing rule:
on NixOS, use the platform — native options beat custom units every time
(real case 2026-08-25: three hand-rolled units became ~60% less code of
pure option declarations in commit af5019dd). Native modules bring
sandboxing, settings-merge pre-starts, user/group creation and firewall
wiring for free, and their ExecStartPre installs config FROM THE NIX STORE,
eliminating the /data/dotfiles host-checkout failure modes of section 9.
Only fall back to the house unit template when no module exists. Contracts,
assay pattern and incident notes: `references/native-media-modules.md`.

### 1. Follow Existing Patterns
Always use an existing working service as a template (e.g., `features/media/jellyfin/default.nix`). Copy its exact structure and modify only the service-specific values.

### 2. Use NFS-Compatible Paths
**Critical**: All services must store data in `/data/services/${servicename}` to be accessible via NFS to Drakkar and Huginn.
- ✅ Correct: `directoryPath = "/data/services/${name}";`
- ❌ Incorrect: Avoid `/mnt/well/services` or other non-exported paths

### 3. Proper Service Structure
Follow this exact structure for all media services:

```nix
{pkgs, ...}: let
  name = "servicename";
  directoryPath = "/data/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      servicename  # or appropriate package name
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Service Description";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.servicename}/bin/servicename [service-specific-args]";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
    # tmpfiles MUST be inside systemd, not at top level
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
      ];
    };
  };

  users = {
    users = {
      "${name}" = {
        isSystemUser = true;
        home = "/home/${name}";
        createHome = true;
        group = "${name}";
        extraGroups = ["data"];
      };
    };
    # groups MUST be inside users, not at top level
    groups = {
      "${name}" = {};
    };
  };
}
```

### 4. Service-Specific Considerations
- **Headless services**: For QBittorrent, use `qbittorrent-nox` package and adjust ExecStart accordingly
- **Apps with no nixpkgs package/module**: never hand-roll a unit around
  `npm start`/`node` — nothing provisions app code, so the unit crash-loops
  and deploy-rs magic-rollbacks every deploy. Two proven tiers:
  - Official OCI image acceptable → `virtualisation.oci-containers.containers.<name>`
    (such units report `inactive` while serving fine — verify by HTTP probe,
    not unit state).
  - Native systemd parity wanted → VENDOR a closed nixpkgs packaging PR
    instead of authoring a derivation from scratch: search
    `api.github.com/search/issues?q=repo:NixOS/nixpkgs+<app>+in:title`,
    download `patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/<n>.diff`,
    extract the package.nix + patches into `pkgs/<app>/`, expose via an
    overlay module in `lib/mk-host.nix`
    (`{nixpkgs.overlays = [(final: prev: {<app> = final.callPackage ../pkgs/<app> {};})];}`
    — path relative to `lib/`). This is how homarr went native
    (PR #430235; its author abandoned upstreaming because Homarr refuses
    bare-metal support). Expect drift vs current nixpkgs: e.g. migrate
    `fetcherVersion = 1` → `3` and regenerate the pnpm hash by building the
    deps derivation once and taking the `got:` hash from the mismatch error.
    Full recipe: `references/homarr-deployment.md`.
    **Postmortem (2026-08-23): the vendored homarr build was REVERTED back
    to the OCI image** — its bundled better-sqlite3 SIGABRT-looped under
    Node 24 (`Statement::~Statement()` →
    `node::RemoveEnvironmentCleanupHook` assert on first DB-touching tRPC
    requests) and no env/secret/state fix cured it. Lessons: (1) vendor a
    source build only if you also control the Node major it builds against;
    (2) when abandoning, revert the WHOLE stack in one commit — feature
    module, the overlay line in `lib/mk-host.nix`, and `rm pkgs/<app>`
    together, or eval breaks on the orphaned overlay; (3) rewrite the
    colocated assay to assert the container shape (image/ports/volumes/
    firewall), since the old suite's unit-level assertions die with the
    units. **Final outcome (2026-08-24): homarr was removed ENTIRELY**
    (`features/media/homarr/` deleted, overlay dropped) and replaced by the
    nixpkgs-native homepage-dashboard restored from git history — see
    section 9b.
- **Homarr config storage** (per homarr.dev docker docs): everything persists in the container's `/appdata` volume — on mimir that's `/data/services/homarr/appdata`, and the actual config (boards, users, integrations) is the SQLite file `appdata/db/db.sqlite`. Back up that one file to have all of Homarr. The sibling `/data/services/homarr/data` mount is unused by the current app version (kept for compatibility). `SECRET_ENCRYPTION_KEY` (64-char hex) is required and lives in the module. The OCI container also accepts `_FILE`-suffixed env vars (its entrypoint inlines `<VAR>_FILE` contents into `<VAR>`) and `PUID`/`PGID` — useful when secrets move to sops-nix/agenix later.
- **Service-specific arguments**: Research each service's required startup arguments (often `--nobrowser --data=${directoryPath}` for *arr suites)

### 5. Common Pitfalls to Avoid
- ❌ Placing `tmpfiles` at top level (must be inside `systemd = {`)
- ❌ Placing `groups` at top level (must be inside `users = {}`)
- ❌ Using non-NFS-compatible paths (`/mnt/well`, `/home`, etc.)
- ❌ Forgetting `Group = "data"` in serviceConfig (needed for NFS access)
- ❌ Incorrect package references (use `${pkgs.servicename}` not hardcoded paths)
- ❌ Mismatched assay stub: the colocated `default.assay.nix` must stub
  `pkgs` with the EXACT attr names the module's `with pkgs;` block uses —
  hyphens included (`{qbittorrent-nox = "qbittorrent-nox";}`, NOT
  `{qbittorrent = ...}` for a module referencing `qbittorrent-nox`). A wrong
  key is an eval-time `undefined variable`, and since assay loads suites
  repo-wide it blocks EVERY commit until fixed.
- ❌ transmission-daemon's `-g` flag is the SETTINGS directory
  (settings.json sits directly inside it), not a data root. Passing e.g.
  `/data/services/transmission` makes the daemon find no settings there,
  generate defaults at that spot (rpc-host-whitelist-enabled=true,
  rpc-whitelist-enabled=true) and every request addressed to the hostname
  answers 403 Forbidden while localhost works. Point `-g` at the same dir
  the declarative-config symlink targets
  (`/data/services/<name>/.config/transmission-daemon`) — real case
  2026-08-25, commit c62a4a88. MOOT since af5019dd: services.transmission
  merges declared settings every start; prefer the native module.
- ❌ Redeploying a long-crash-looped daemon without clearing its lock/state
  files: a crashed app can leave `.flexget-lock`-style locks OUTSIDE systemd
  lifecycle; the new unit dies instantly ("Another process (PID ...) is
  running"), switch-to-configuration exits non-zero, and deploy-rs
  magic-rollback RESURRECTS the broken old units. Stop + reset-failed +
  remove the lock BEFORE redeploying. Full incident:
  `references/native-media-modules.md`.
- ❌ Hand-rolled units when nixpkgs has a native module (see Step 0) —
  the user corrected this directly ("we are on NixOS"). Custom units lose
  sandboxing, settings-merge pre-starts, user/group creation, firewall
  wiring, and they re-create host-clone config dependencies that native
  store-installed configs eliminate.
- ❌ Missing test args: if the module declares `{config, lib, pkgs, ...}`,
  the assay import must pass all of them (`config = {}; lib = {};`) even if
  unused — "function called without required argument".
- ❌ Stale host assays: when a cleanup commit deletes a profile a host
  assay still asserts (e.g. `profiles/mobile.nix`), update that assay in
  the same commit — it keeps failing repo-wide otherwise.
- ❌ Trusting a module's stale TODO comment over reality: before declaring
  an app "unavailable", check nixpkgs TODAY — `nix eval --raw
  nixpkgs#<name>.name`, build it once, confirm the bin name matches the
  module's ExecStart (whisparr's "not available on NixOS yet" header was
  months out of date; the package worked first try).
- ❌ Removing a superseded feature: grep for references repo-wide first;
  if only its own dir + suite mention it, `git rm -r` needs zero other
  edits. Commit removals separately from new work.
- ❌ Oneshot wiring units that assume apps are ready: any unit that calls
  another service's HTTP API at boot must poll that port until ANY HTTP
  response arrives, and must not fail the whole unit on one target's
  error — see section 8.
- ❌ Pinning a Grafana datasource `uid` in provisioning when that datasource
  already exists in the DB: Grafana 13 aborts startup ("data source not
  found") → start-limit-hit → magic rollback. Omit the uid; dashboards
  reference the existing DB-assigned one. Dashboard provider paths must be
  DIRECTORIES (a file path silently provisions nothing). See
  `references/grafana-provisioning.md`.
- ❌ Multi-process upstream apps (web + websocket + cron tasks, like homarr):
  do NOT launch side processes from `preStart` with `&` — they are unsupervised
  and their env-validation failures surface confusingly. Give each process its
  own systemd unit (`homarr`, `homarr-wss`, `homarr-tasks`, plus a oneshot
  `homarr-migrate` with `RemainAfterExit` and web's `requires`). Units only
  *start* if something pulls them in: `bindsTo`/`after` couple lifecycle but
  each still needs `wantedBy = ["multi-user.target"]`.
- ❌ Deploying an env-only module change and expecting new variables to apply:
  systemd sees the same ExecStart string and does NOT restart the unit —
  unchanged units keep running with stale env. Force it by changing the unit
  structurally (new ExecStart, split units) or restarting explicitly.
- ❌ Duplicate collector entries / a collector in both enabled and disabled
  lists of `services.prometheus.exporters.node`: NixOS renders them as
  repeated CLI flags; Go's parser exits(1); systemd start-limit-hit;
  deploy-rs magic-rollbacks (flaky deploys). See `nixos-deploy-rs` skill.

### 6. Verification Steps (unit state lies — probe the port)
Unit state alone misleads in both directions:
- oci-container units report `inactive` while the app serves fine (unit hands
  off to the daemon) — verify by HTTP, not systemctl.
- .NET apps (readarr) are `active` before they listen — allow a warm-up sleep,
  then check the port.
- A unit can be silently `failed` across many deploys: `nixos-rebuild switch`
  does NOT restart unchanged units, so a service that failed once (e.g. port
  collision at first enable) stays down while every later deploy "confirms".
After creating/modifying a service module:
1. Check syntax: `nix eval --raw --json '(import ./path/to/module.nix {})'`
2. Validate with fleet: `bin/fleet check mimir`
3. Test build: `nix build .#mimir.config.system.build.toplevel --keep-going` (ignore warnings about overseaserr/grafana)
4. Confirm result symlink is created
5. Deploy, then smoke-check: `systemctl is-active <unit>` AND
   `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:<port>/` —
   any code <500 means the app is up (302/307 redirects are healthy).

### 7. Port collisions with mimir's rootless container stack
Mimir runs a rootless docker stack (rootlesskit) that owns host ports
independently of NixOS: 5432 (logto-db postgres), 5433 (yb-tserver), 9000
(yb-tserver UI), plus 6379/5672/4317-4318/10000-10002. Symptom: the NixOS
service crash-loops with "address already in use" or binds nothing while the
port answers with the WRONG app (404 from yugabyte, not grafana).
Triage: `sudo ss -tlnp | grep :<port>` — `rootlesskit` in users:() means the
container stack owns it. Fix on OUR side: pick a free port for the NixOS
service (grafana 9000→3000, invidious' postgresql →5434), never remap the
user's containers. Check the port is free before deploying.

### 8. Declarative *arr inter-service wiring
Six apps as of 2026-08-24: prowlarr/sonarr/radarr/readarr/lidarr/whisparr.
API keys are declared in
`features/media/api-keys.nix` (single source of truth, committed plaintext —
fine for a private repo, rotate if it ever leaves your control) and enforced
into each app's config.xml by an idempotent `arr-api-key-seed` oneshot.
`features/media/arr-wiring.nix` registers all five non-Prowlarr apps in Prowlarr
(`prowlarr-sync` oneshot) so indexers propagate without manual key copying.
Two hard rules from production: prowlarr-sync must WAIT for each app's port
to answer before registering (Prowlarr connectivity-tests at registration;
systemd `after=` means started, not listening) and must tolerate per-app
failures — one 400 used to fail boot activation and trigger deploy-rs
magic-rollback of the whole deploy. Adding an app touches FOUR spots in one
commit: api-keys.nix (+ assay app set), arr-wiring.nix apps/implementations/
CATEGORIES (+ assay apps list), host import. Prowlarr API quirks are
non-obvious — see
`references/arr-api-wiring.md` before touching that module.
Remaining manual steps (no API bootstrap): indexers themselves, download
client + root folder per app — these live in each app's SQLite db
(`prowlarr.db`), NEVER in config.xml; when asked to "commit indexer changes",
diff the host clone first (what actually drifts in config.xml is
auth/metadata settings). Homarr was replaced by homepage-dashboard
(2026-08-24) — its tiles are plain Nix attrs in
`features/monitoring/homepage-dashboard/default.nix` again.

### 9. Cursor-pattern declarative app config (symlinked from the repo)

Apps whose own UI rewrites their config can still be declared in-repo: keep the
config under the feature dir mirroring its real path
(`features/media/<svc>/config/config.xml`; desktop-app precedent:
`features/programming/cursor/.config/Cursor/…` + `bin/link-files-nixos`),
and add an activation script that symlinks it into the service data dir
(all five arr services ship it as of 2026-08-24; start from
`templates/arr-declarative-config.nix`). Non-negotiables: backup a divergent real
file once before first link (`cmp -s` guard), `ln -sfn` for idempotence,
degrade gracefully when the repo checkout is missing, make the source
group-writable (`chgrp data`, 0664) so UI writes flow back through NFS
ownership. Prereq on the serving host: a dotfiles clone at `/data/dotfiles`.
Assay suites assert wiring shape + secret parity against `api-keys.nix`,
never echoing key material. Detail: `references/declarative-config-symlink.md`
(fleet-replication checklist, UI-edit sync-back/drift flow, auth-decision +
verification-consent lessons).
**Host checkout freshness**: every unit/script that reads `/data/dotfiles`
(symlink source, homarr-sync, homarr-export) resolves against whatever commit
the HOST clone sits at — deploying from drakkar does NOT update mimir's
clone. After pushing, `git -C /data/dotfiles pull --ff-only` on the serving
host, or the sync unit logs its graceful-skip line ("incomplete … skipping")
and silently does nothing while systemd shows success. Publishing commits
made ON the host: mimir's `/data/dotfiles` remote is HTTPS with no stored
credentials (push fails with askpass errors) — fetch the commit into
drakkar (`git fetch ssh://tom@mimir/data/dotfiles main` +
`git merge --ff-only FETCH_HEAD`) and push from there.
Real case (2026-08-25, flexget rollout): a unit whose ExecStartPre COPIES
the repo config (`install -m644 <repo>/config.yml <data>/config.yml`)
crash-loops when the host clone is stale — install cannot stat the missing
source — while the symlink pattern degrades gracefully. If you use the
copy-instead-of-link shape, either make ExecStartPre tolerate a missing
source (log + continue so the daemon can boot on its live file) or treat
the post-push host pull as MANDATORY before the deploy, not optional
cleanup.

**SQLite-backed apps (homarr): reconciler/export pattern instead of symlinks.**
A symlinked config file is impossible when the app persists everything in one
sqlite DB — the UI writes rows, not files. Pattern shipped for homarr
(`features/media/homarr/{board.json,reconcile.js,export.js}`, commit cad0d3e7):
- `board.json` declares apps + integrations + secret values (integration API
  keys sourced from `api-keys.nix` conventions).
- A `homarr-sync` oneshot (after the container unit) does
  `podman cp board.json/reconcile.js <ctr>:/tmp/` then `podman exec <ctr> node /tmp/reconcile.js /tmp/board.json`.
- `reconcile.js` is UPSERT-ONLY: creates integrations/app tiles/grid
  positions/home-board pointer, never deletes undeclared rows, so manual UI
  additions survive every deploy.
- Secrets MUST match homarr's own crypto: `aes-256-cbc`, key = hex-decoded
  `SECRET_ENCRYPTION_KEY`, random 16-byte IV, stored as
  `"<ciphertext-hex>.<iv-hex>"` in `integrationSecret(kind,value,integration_id)`
  (PK `(integration_id,kind)`).
- An `homarr-export` timer (`startAt = "hourly"`) dumps live state back to
  JSON and refreshes `board.json` in `/data/dotfiles` when it differs — UI
  edits land on disk for review/commit. NEVER export secret values; export
  only key names (`"<kind>": "SET-IN-api-keys-nix"`).
- INTROSPECT BEFORE INSERTING: run `PRAGMA table_info(<t>)` inside the
  container first. Real traps found live: the `app` table has NO `url`
  column (it's `href`), and a fresh `board` row needs ~8 NOT NULL defaults
  (background_image_attachment/repeat/size, primary_color, secondary_color,
  opacity, disable_status, item_radius) — bare `(id,name,is_public)` fails
  with opaque `SQLITE_CONSTRAINT_NOTNULL`.
Detail: `references/homarr-board-sync.md`.

### 9b. Replacing a third-party dashboard with a nixpkgs-native one (homepage-dashboard)

When a third-party dashboard keeps costing more than it gives (native build
breaks, OCI image opaque, declarative-config layer bolted on), prefer the
nixpkgs-native alternative if one exists. Homepage (gethomepage.dev) ships as
`services.homepage-dashboard` in nixpkgs — fully declarative Nix
(`settings`, `bookmarks`, `services`, `widgets` attrs), no containers, no
sqlite, no sync machinery. Recovery recipe used on mimir (commits 8f501e36 +
4b7ea498):

1. Recover the old module from git history:
   `git show <rev>^:features/monitoring/<name>/default.nix` (find the rev via
   `git log --all --diff-filter=D -- "*<name>*"` or `git log --all --grep=`).
2. Delete the whole replacement feature dir + its host import in the same
   commit; add the restored module's import to the host configuration.
3. **Check the port against TODAY'S fleet, not the historical config.** The
   restored module still bound its 2024-era port 8080, which qbittorrent-nox's
   WebUI now owns → EADDRINUSE crash-loop → start-limit-hit. Pick a free port,
   update the assay assertion, and add a tile/link for whatever now occupies
   the old port.
4. Rewrite the colocated assay to assert real option values
   (`hp.enable`, `hp.listenPort`, list lengths) instead of the old
   file-nonempty stub.

Verify live: unit active + HTTP probe of the new port from the host AND from
another fleet machine; confirm the old service's port is closed and zero old
units remain (`systemctl list-units | grep -i <old>`).

## Deployment
Once validated:
```bash
bin/fleet deploy mimir --dry-activate   # Always test first
bin/fleet deploy mimir                   # Actual deployment
```

**Watch your working directory.** Terminal state persists across calls; a
leftover `cd /tmp/<worktree>` from an earlier verification step makes every
later command — including `bin/fleet deploy` and `nix eval .#` — run against
a STALE snapshot of the repo. A deploy then "confirms" while shipping the old
config (real case: jellyfin deploy verified against a frozen worktree). Pin
`workdir` explicitly on every command, or `cd` back immediately after
worktree checks.

## References
- See `features/media/jellyfin/default.nix` for the canonical template
- Refer to existing services in `features/media/` for service-specific details
- Check `hosts/mimir/configuration.nix` for how services are imported
- Repo gate: `devenv shell -- assay run .` (repo-wide suite load) + `nix flake check`; commit via `devenv shell -- git commit` with an explicit pathspec — see `nixos-managing` skill, "Committing in this repo"
- `references/homarr-deployment.md` — homarr native systemd deployment:
  vendored-package recipe (nixpkgs PR extraction + overlay), unit topology,
  env contract, config storage (/appdata → appdata/db/db.sqlite),
  verification quirks
- `references/homarr-board-sync.md` — declarative board.json → sqlite
  reconciler + hourly export pattern for the OCI container: container/DB
  schema facts, secret encryption format, sync/export unit design, open
  NOT NULL constraint item
- `references/grafana-provisioning.md` — Grafana uid traps (never pin a uid
  over an existing DB datasource), provider-path-must-be-directory, live-uid
  extraction without sqlite3, fleet.json dashboard shape, prometheus host
  labels, reset-failed recovery
- `references/arr-alternatives.md` — rated alternatives to the arr ecosystem
  under the flat-file-config requirement (Jackett/Transmission/Medusa,
  NZBHydra2, FlexGet single-manager answer; why autobrr/qui/Riven/Flemmarr
  fail), with stars/activity/nixpkgs-fit per candidate
- `references/native-media-modules.md` — jackett/transmission/flexget
  cutover to native NixOS modules: module contracts (transmission settings
  merge + package pin, flexget store-embedded YAML, jackett dataDir),
  option-contract assay pattern for modules that cannot be stub-imported,
  .flexget-lock x magic-rollback incident and recovery
- `references/flexget-native-module-gotchas.md` — services.flexget on
  nixpkgs: missing cryptography dependency (override recipe), Web UI stub
  vs PyPI-wheel prebuilt bundle (webui.nix splice), three-layer
  .flexget-lock race cures (pre-start heal / mkForce ExecStop "" /
  activation-script quiesce), and the deploy-log debugging path for
  rollback loops

## Troubleshooting
- If `nix flake check` shows only warnings about overseaserr/grafana, these are safe to ignore (configuration warnings, not build errors)
- If service fails to start, check `journalctl -u servicename` on the target host
- Verify NFS access: On Drakkar/Huginn, check if `/mnt/mimir/services/servicename` is accessible