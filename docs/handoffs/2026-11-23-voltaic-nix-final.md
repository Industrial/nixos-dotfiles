# Voltaic Nix, Layers A + B: final summary (2026-11-23)

Supersedes the "remaining work" sections of `2026-11-22-voltaic-nix-layer-a.md` and
`.maestro/handoffs/2026-11-22-evening-voltaic-nix.md`. Board: https://github.com/users/Industrial/projects/3.
Every tool below is Voltaic `=0.3.0` + id_effect 0.13.0, standalone under `rust/tools/`, and was deployed
by vdeploy and probed read-only on the host before its issue was closed.

## Fleet

- **drakkar** (workstation, builder, cache) and **mimir** deploy through **vdeploy**.
  - Deploy mode, health-checked with automatic rollback.
  - Since #269, only heads of main whose GitHub signature verifies are deployed.
  - comin is gone from both hosts (#275); huginn and muninn, permanently offline, still carry it.
  - Rollback: `fleet deploy <host> --legacy` (deploy-rs).
- Merge to switched: drakkar median ~1.4 min, mimir ~3.7 min. No plan cancellations.

## What was replaced (the default path)

| Was | Now | Rollback |
|---|---|---|
| comin | vdeploy (#160, #223, #239), comin tombstone removed (#275) | `fleet deploy <host> --legacy` |
| nixos-rebuild / nh as the local switch | vswitch (#250); `bin/update/system` uses it | `features.cli.vswitch.enable = lib.mkForce false` (nh still installed) |
| ad-hoc host builds | vci on the cache host, every host per main commit and same-repo PR (#254) | `features.nix.vci.enable = lib.mkForce false` |
| re-evaluating a commit vci already evaluated | veval: signed evaluation records from vci, served by vcache (#285, #286) | `features.nix.vdeploy.evalCache.enable = lib.mkForce false` |
| `nix store diff-closures` in the update notifier | `vdiff --json` (#270); the notifier is no longer a flake input | `differ = "nix"` |
| nix-daemon for 3 read ops | vdaemon-proxy answers IsValidPath, QueryPathInfo, QueryValidPaths natively (#268) | `features.nix.vdaemon-proxy.native = lib.mkForce []` |
| `nix-collect-garbage` / auto-optimise | vgc (weekly; first run 2026-11-23: 26,322 paths, 44 GiB of links) and vopt (nightly) | peer dotfiles-23 |
| perl user/group activation | userborn (drakkar) | per `docs/runbooks/userborn.md` (now VM-verified, #274) |
| activation scripts for user files | vfiles, plus `vfiles.service` after userborn (#271) | `vfiles.legacy` |

Also live (Layer A): nix-store-core, vcache, vfetch serve (narinfo disk cache #284; NAR uploads stream from a reader #281), vbuild, vmon, vwhy, vgen, vverify, vhealth, vexporter + dashboards, vlocate (complements nix-index, by the user's scope change).

## Kept, and why

- **nix-daemon** stays the default for writes and builds (user decision on #244).
- **nix-index / comma** stay: vlocate complements them (user decision on #245).
- **`nix build --max-jobs 0`** stays as vdeploy's fetcher. vfetch measured as ≤2 s of a ~50 s cycle (#221).
- **Full vdeploy clone:** a shallow one saves ~256 MB only (#221).
- **Read ops left forwarded:** QueryReferrers, QueryPathFromHashPart and NarFromPath had too little traffic to be worth answering natively (#224).
- **vfetch range splitting:** one connection already fills the link (#216).
- **vcache vs harmonia benchmark:** it can't change what we run (#146).
- **WoW addons stay in the flake source** (user: "WoW stays"). The cost is ~1.2 GB per evaluated commit until vopt/vgc.

## Hygiene fixed this round

- Whole-directory store copies (`builtins.getFlake "<dir>"`, `path:`) are fixed and guarded (#267, `bin/ci/flake-refs`). Two of them had leaked the Claude login.
- vgc's first run collected every copy, including the two credential paths (#266).
- CI's cargo-nix-drift now really diffs (#272).
- Flaky notifier test fixed (#283).
- Headless hosts no longer fail the notifier (#278).

## Waiting on the user

1. **Rotate the Claude Code login** (log out and back in). The credential was world-readable in the store from 2026-11-21 13:14 to 2026-11-23 00:00.
2. **#241 vswitch / #245 vlocate**: run `bash ~/.dotfiles/.tmp/vnla/user-probe-b.sh` as tom (no root; the agent allowlist reserves these two commands for you). Both are deployed on both hosts.
3. **#184 / #208 lanzaboote**: create the keys (`bash -c 'sudo nix run nixpkgs#sbctl -- create-keys'`), back up `/var/lib/sbctl`, then mark #208 ready.
4. **#185 /etc overlay**: built and VM-proven for a live switch in and out (#249); enabled on no host until you say so.
5. **#189 / #228 / #247 vbump GitHub App**: create the App and its secrets (steps on #189); then decide the auto-merge policy for flake bumps.

## Waiting on time

- **#257**: re-measure superseded plans on 2026-11-29.
- **#256**: deploy-rs phase B, after about a week of `wake` as the default (from 2026-11-22).
- **#287**: make drakkar hit its own eval-cache record (vci host order).
- **#150 / #240** (tracking): close when the items above are closed.

Out of programme, left as they were: #127 (pre-programme quality follow-ups; operator items) and #169 (deepsec: the user chose "proceed without").
