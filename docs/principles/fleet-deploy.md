# Fleet deploy principle

## Statement

Push-deploy NixOS hosts from a **single root flake** using **deploy-rs only**. One primary activator per generation stream.

## Invariants

1. **One flake, many hosts** — `nixosConfigurations.{drakkar,huginn,mimir}` at repo root; per-host Disko/hardware stays under `hosts/<name>/`.
2. **deploy-rs only** — No Colmena hive, no parallel activation tools on the same hosts.
3. **Comin absent** — pull-deploy must not race push-deploy (module removed from tree).
4. **Operator SSH** — Fleet control uses operator keys + `bin/fleet`; Hermes is not the access plane.
5. **Rollback evidence** — magicRollback stays on unless changing SSH/listen addresses; exercise rollback before trusting fleet deploy.

## When to revisit

- Weekly need for Colmena tags or `deployment.keys` per host
- More than ~5 hosts without deploy-rs parallelism limits
- sops-nix / shared secrets platform (separate mission)
