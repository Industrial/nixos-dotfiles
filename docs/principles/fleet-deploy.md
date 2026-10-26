# Fleet deploy principle

## Statement

Deploy NixOS hosts from a **single root flake**. `deploy-rs` is the operator's activator; **comin** is the unattended floor that converges hosts the operator could not reach. `origin/main` is the only source either one activates from.

## Invariants

1. **One flake, many hosts** — `nixosConfigurations.{drakkar,huginn,mimir,muninn}` at repo root; per-host Disko/hardware stays under `hosts/<name>/`.
2. **Two activators, one source** — deploy-rs (push) and comin (pull) both activate `origin/main` only. No Colmena hive, no third activator.
3. **Push before deploy** — comin reverts any activation not reachable from `origin/main`. Unpushed experiments go to the `testing-<hostname>` branch, which comin applies with `test` (never written to the bootloader). See ADR-0002.
4. **Operator SSH** — Fleet control uses operator keys + `bin/fleet`; Hermes is not the access plane.
5. **Rollback is manual on this fleet** — `magicRollback` and `autoRollback` are both **disabled** in `flake.nix` (dbus subscription timeouts during switch). A failed activation does **not** self-revert: `--dry-activate` first, and keep console access for risky changes.

## When to revisit

- Re-enabling `magicRollback` once the dbus timeout is understood — manual-only rollback is a standing risk, not a preference
- Weekly need for Colmena tags or `deployment.keys` per host
- More than ~5 hosts without deploy-rs parallelism limits
- sops-nix / shared secrets platform (separate mission)
