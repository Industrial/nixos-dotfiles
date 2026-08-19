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
