---
name: nixos-deploy-rs
description: >-
  Deploy NixOS fleets with deploy-rs on a unified flake. Use when adding
  deploy.nodes, magicRollback, interactiveSudo, root flake unification,
  disabling comin, or remote switch of hosts (drakkar/huginn/mimir). Not for
  Colmena or Hermes agent wrappers.
---

# NixOS deploy-rs Fleet

## Overview

Push-deploy NixOS hosts from a **single root flake** using **deploy-rs only**.
Per-host modules (`disko.nix`, `hardware.nix`, `filesystems.nix`) stay under
`hosts/<name>/`; the root flake only exposes `nixosConfigurations` + `deploy`.

## Dependencies

- `nixos-managing` — rebuild/rollback/anti-patterns
- `scientific-method` — when choosing between deploy tools or flake topologies

## Locked decisions (this repo)

| Topic | Decision |
|-------|----------|
| Deployer | deploy-rs only (Colmena deferred) |
| Flake | Unified root `flake.nix` |
| Comin | Disabled while push-deploy is primary |
| Hermes | Out of scope |

## Workflow

### 1. Preconditions
- OpenSSH key-only on targets; test `ssh <host> hostname`
- Prefer wheel user + `interactiveSudo = true` for humans
- Disable `magicRollback` only when changing SSH port/IP/listen

### 2. Flake shape
```nix
deploy.nodes.<host> = {
  hostname = "<host>";
  profiles.system.path =
    deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.<host>;
};
checks = builtins.mapAttrs (_: c: c.deployChecks self.deploy) deploy-rs.lib;
```

### 3. Operator commands
```bash
nix flake check
deploy .#huginn --dry-activate   # or project bin/fleet check huginn
deploy .#huginn
deploy .                         # all nodes
```

### 4. Conflict with comin
Never leave `services.comin.enable = true` while deploy-rs is primary.

## Common Mistakes

- Activating with Colmena **and** deploy-rs on the same generation stream
- Assuming Colmena has magicRollback / `colmena rollback` (it does not)
- Moving Disko into root flake body (keep modules under `hosts/`)
- Leaving comin enabled → double apply races
- `services.prometheus.exporters.node` list mistakes (`enabledCollectors`
  duplicated entries, or a collector in both enabled and disabled lists):
  NixOS renders each entry as a literal flag, so ExecStart gets e.g.
  `--collector.tcpstat --collector.tcpstat`. Go's flag parser rejects repeats
  → exit(1) → systemd crash-loops to start-limit-hit → activation reports
  "units failed" → deploy-rs magic-rollbacks. Symptom is *flaky* deploys:
  failure depends on where the switch's unit-state check lands in the
  crash/restart cycle. Grep the target's journal for
  `cannot be repeated, try --help` to confirm. After fixing the module,
  also run `systemctl reset-failed <unit>` (or redeploy) on hosts left in
  start-limit-hit state, or they stay broken between deploys.
- Trusting per-file audits of NixOS list options. List options
  **concatenate across module imports**: two modules each setting
  `services.prometheus.exporters.node` with internally-clean lists still
  yield a duplicated merged list (bit a host importing both
  `prometheus-exporter` and `prometheus`). Fix by importing only one module
  that configures the exporter, and always verify the **evaluated merged
  config**, not the source files — use
  `scripts/verify-node-exporter-flags.sh` (bash+jq, no python needed).

## Debugging flaky deploys

1. Run the deploy 3-5x, capturing each full log (`... > attempt-N.log 2>&1`).
   One success (or two or three) proves nothing — the flake is a timing race
   between unit crash and the switch's unit-state check.
2. Read the failing log in full: deploy-rs prints the failing unit plus the
   target's journal lines before rolling back.
3. Grep the unit's own stderr on the target:
   `sudo journalctl -u <unit> --since -30min`. The error message names the
   cause (e.g. `flag 'collector.X' cannot be repeated`).
4. Check live state (`systemctl is-active/status <unit>`):
   `start-limit-hit` = crash-loop; the unit stays failed between deploys
   until `reset-failed` or a good deploy lands.
5. Remote commands: a target's login shell may be nushell — use
   `ssh <host> -- bash -c '"..."'`.
6. After fixing, verify the merged config evaluates clean (script above),
   then soak 10+ consecutive deploys before calling it fixed.

## Committing the fix

This repo's hooks run through devenv (see `nixos-managing` → "Committing in
this repo"): use `devenv shell -- git commit …`, follow Conventional Commits,
and land repairs of broken-in-HEAD assay suites as a separate `test:` commit
BEFORE the functional change — prek evaluates the exact staged tree, so a
pathspec-limited commit still runs suites against HEAD-with-only-that-fix.
