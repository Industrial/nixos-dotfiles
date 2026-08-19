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

## Do

1. Use root flake `deploy.nodes` + `deploy .#<host>`
2. Keep per-host Disko/hardware under `hosts/<name>/`
3. Disable comin while push-deploy is primary
4. Operator SSH via `~/.ssh/config` — not `~/.hermes/`

## Do not

- Install Hermes-only deploy keys or `~/.hermes/bin/nixos-mgmt`
- Activate with Colmena and deploy-rs on the same generation stream
- Invent `colmena rollback` / `colmena update` subcommands
