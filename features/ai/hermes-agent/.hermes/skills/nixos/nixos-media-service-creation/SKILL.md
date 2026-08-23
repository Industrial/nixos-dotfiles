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
- **Apps with no nixpkgs package/module** (homarr): do NOT hand-roll a systemd unit running `npm start`/`node` — nothing provisions the app code, so the unit crash-loops and deploy-rs magic-rollbacks every deploy. Use `virtualisation.oci-containers.containers.<name>` with the official OCI image instead (see `features/media/homarr/default.nix`); such units report `inactive` while serving fine — verify by HTTP probe, not unit state.
- **Homarr config storage** (per homarr.dev docker docs): everything persists in the container's `/appdata` volume — on mimir that's `/data/services/homarr/appdata`, and the actual config (boards, users, integrations) is the SQLite file `appdata/db/db.sqlite`. Back up that one file to have all of Homarr. The sibling `/data/services/homarr/data` mount is unused by the current app version (kept for compatibility). `SECRET_ENCRYPTION_KEY` (64-char hex) is required and lives in the module.
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
- ❌ Missing test args: if the module declares `{config, lib, pkgs, ...}`,
  the assay import must pass all of them (`config = {}; lib = {};`) even if
  unused — "function called without required argument".
- ❌ Stale host assays: when a cleanup commit deletes a profile a host
  assay still asserts (e.g. `profiles/mobile.nix`), update that assay in
  the same commit — it keeps failing repo-wide otherwise.
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
API keys for prowlarr/sonarr/radarr/readarr/lidarr are declared in
`features/media/api-keys.nix` (single source of truth, committed plaintext —
fine for a private repo, rotate if it ever leaves your control) and enforced
into each app's config.xml by an idempotent `arr-api-key-seed` oneshot.
`features/media/arr-wiring.nix` registers all four apps in Prowlarr
(`prowlarr-sync` oneshot) so indexers propagate without manual key copying.
Prowlarr API quirks are non-obvious — see
`references/arr-api-wiring.md` before touching that module.
Remaining manual steps (no API bootstrap): indexers themselves, download
client + root folder per app, homarr tiles.

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
- `references/homarr-deployment.md` — homarr config storage (/appdata →
  appdata/db/db.sqlite), docs sources, runtime/verification quirks

## Troubleshooting
- If `nix flake check` shows only warnings about overseaserr/grafana, these are safe to ignore (configuration warnings, not build errors)
- If service fails to start, check `journalctl -u servicename` on the target host
- Verify NFS access: On Drakkar/Huginn, check if `/mnt/mimir/services/servicename` is accessible