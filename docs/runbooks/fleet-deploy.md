# Fleet deploy runbook

Operator push-deploy for Drakkar, Huginn, Mimir, and Muninn using **deploy-rs** on the **root flake**.

> **Push before you deploy.** comin converges every host to `origin/main` every
> 300s (ADR-0002), so activating an uncommitted or unpushed tree gets reverted
> within five minutes. Commit and push first, or push to `testing-<hostname>`.

## Prerequisites

1. Root flake checked out at `~/.dotfiles` (or `$DOTFILES_ROOT`).
2. Operator SSH key on target (`tom@<host>`), tested over **Tailscale**.
3. SSH as `tom` (`sshUser`); activate as `root` (`user`) via **passwordless sudo** (`interactiveSudo = false`; NOPASSWD in `features/fleet/operator-ssh.nix`).
4. **Operator pubkeys** in `features/fleet/operator-ssh.nix` — one Ed25519 slot per host (all four enrolled; muninn 2026-10-26).
5. Client SSH uses `IdentitiesOnly` for `drakkar huginn mimir muninn` (system `/etc/ssh/ssh_config`).

## Local validation

```bash
cd ~/.dotfiles
nix flake check
bin/fleet check huginn    # includes --dry-activate when SSH works
```

## Deploy one host

```bash
bin/fleet deploy huginn --dry-activate   # always first on a new generation
bin/fleet deploy huginn
```

Deploy all nodes (continues if one host fails; non-zero exit if any failed):

```bash
bin/fleet deploy all
```

Underlying CLI: `nix run github:serokell/deploy-rs -- .#<host>`.

## Rollback — MANUAL ONLY on this fleet

**There is no automatic rollback.** `flake.nix` sets both `magicRollback = false`
and `autoRollback = false` (the dbus monitor times out when systemd/journald
restart mid-switch). A failed activation stays applied until you revert it by
hand, so `--dry-activate` first and keep console access for anything that could
cut SSH.

Manual rollback on host:

```bash
sudo nixos-rebuild switch --rollback
# or pick a generation:
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

Re-enabling `magicRollback` is tracked as follow-up in
`docs/principles/fleet-deploy.md`; until then treat every deploy as
non-self-healing.

## Emergency local rebuild

When SSH is broken:

```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake ".#$(hostname)"
```

Or legacy path via host shim (same root eval):

```bash
cd ~/.dotfiles/hosts/$(hostname)
sudo nixos-rebuild switch --flake ".#$(hostname)"
```

## Network path

**Default:** Tailscale mesh (`services.tailscale.enable = true`). Public firewall stays closed.

## Comin (pull convergence)

comin is **enabled on all four hosts** (`features/fleet/comin.nix`, ADR-0002).
It polls `origin/main` every 300s and runs `switch`, so an offline host
self-heals on next boot without an operator.

```bash
ssh <host> systemctl status comin.service
ssh <host> journalctl -u comin.service -n 50
curl -s http://<host>:4243/metrics | grep '^comin_'   # over tailscale0
```

Key metrics: `comin_last_deployment_failed`, `comin_last_build_failed`,
`comin_last_eval_failed`, `comin_need_to_reboot`.

**Operating rules**

| Situation | Do this |
|---|---|
| Normal change | commit → push → `bin/fleet deploy <host>` (comin's next poll is then a no-op) |
| Experiment on one host | push to `testing-<hostname>`; comin applies it with `test`, so a reboot discards it |
| Hands-on intervention | `sudo systemctl stop comin.service` first, or it will revert you within 300s |
| Host was offline | one manual `bin/fleet deploy <host>` installs comin; convergence is automatic from then on |

## Related docs

- ADR: `docs/adr/0001-fleet-deploy-rs.md`
- Principle: `docs/principles/fleet-deploy.md`
- Maestro mission: `pln-mt0fxitc-f74sm9`
- Remote builds: `docs/runbooks/nix-remote-build.md`
