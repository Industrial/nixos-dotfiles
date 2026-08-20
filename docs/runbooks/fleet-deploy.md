# Fleet deploy runbook

Operator push-deploy for Drakkar, Huginn, and Mimir using **deploy-rs** on the **root flake**.

## Prerequisites

1. Root flake checked out at `~/.dotfiles` (or `$DOTFILES_ROOT`).
2. Operator SSH key on target (`tom@<host>`), tested over **Tailscale**.
3. SSH as `tom` (`sshUser`); activate as `root` (`user`) via **passwordless sudo** (`interactiveSudo = false`; NOPASSWD in `features/fleet/operator-ssh.nix`).
4. **Operator pubkeys** in `features/fleet/operator-ssh.nix` — one slot per host (`drakkar` enrolled; huginn/mimir filled from those machines later).
5. Client SSH uses `IdentitiesOnly` for `drakkar huginn mimir` (system `/etc/ssh/ssh_config`).

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

Deploy all nodes:

```bash
bin/fleet deploy all
```

Underlying CLI: `nix run github:serokell/deploy-rs -- .#<host>`.

## Rollback (magicRollback)

If activation fails health checks, deploy-rs rolls back to the previous generation automatically.

Manual rollback on host:

```bash
sudo nixos-rebuild switch --rollback
# or pick a generation:
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

**Disable magicRollback** only when changing SSH listen address, port, or firewall rules that affect deploy connectivity — then use local console.

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

## Comin must stay off

Do not re-enable comin while deploy-rs is primary — dual apply races NixOS generations.

## Related docs

- ADR: `docs/adr/0001-fleet-deploy-rs.md`
- Principle: `docs/principles/fleet-deploy.md`
- Maestro mission: `pln-mt0fxitc-f74sm9`
