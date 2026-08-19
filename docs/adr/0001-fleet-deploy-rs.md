# ADR-0001: Fleet push-deploy with deploy-rs

**Status:** Accepted  
**Date:** 2026-08-19  
**Mission:** `pln-mt0fxitc-f74sm9`

## Context

Three NixOS hosts (drakkar, huginn, mimir) were managed via per-host flakes and comin pull-deploy. The 2026-08-19 history plan proposed Colmena + deploy-rs + Hermes wrappers, which introduced dual-activation risk and fictional Colmena rollback semantics.

## Decision

1. **Unified root flake** at repository root with `nixosConfigurations` for all hosts.
2. **deploy-rs only** for remote activation (`magicRollback`, `activate.nixos`).
3. **Disable comin** on all hosts while push-deploy is primary.
4. **Operator access** via OpenSSH (key-only) and Tailscale mesh; `bin/fleet` wraps deploy-rs.
5. **Hermes and Colmena are non-goals** for this mission.
6. **Per-host modules preserved** — `hosts/<name>/disko.nix`, `hardware.nix`, `filesystems.nix` unchanged in location.

## Consequences

### Positive

- Single lockfile and one `nix flake check` for the fleet
- Documented rollback path via deploy-rs magicRollback
- No race between comin pull and operator push

### Negative

- Loses Colmena tag/`deployment.keys` ergonomics until revisited
- Requires SSH path before first remote deploy (Tailscale preferred)
- High-risk changes need local console access during SSH rollout

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Colmena + deploy-rs hybrid | Dual activators race generations |
| Colmena only | No magicRollback; different eval model |
| Per-host flakes + deploy-rs | Three locks; deploy attr duplication |
| Hermes agent SSH keys | Out of scope; operator keys instead |

## Threat model (summary)

| Threat | Mitigation |
|--------|------------|
| Operator SSH key compromise | Ed25519 keys, no passwords, Tailscale ACLs, rotate keys |
| Generation race (comin + deploy) | comin disabled; assay asserts |
| Failed activate bricks SSH | magicRollback; `--dry-activate` first; keep local rebuild path |
| magicRollback partition full | Monitor `/nix/store`; GC policy in base profile |
| Untrusted network SSH | Tailscale preferred; firewall closed on public iface |

Full exercise evidence belongs in Maestro task `tsk-mt0fxmz9-nkdmw8` (`threat-model` kind).
