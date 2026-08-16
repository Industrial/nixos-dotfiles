# nixos-update-notifier

Check whether a NixOS host flake would update, then **notify with the exact packages** that would change (name + version delta).

Uses the session D-Bus (`org.freedesktop.Notifications`) so GNOME shows a normal banner and tray entry — same channel as `notify-send`.

## What it does

1. Runs `nix flake update --output-lock-file` into a temp lock (does **not** modify your repo `flake.lock`).
2. If the lock is unchanged → exits quietly (“up to date”).
3. If the lock would change → builds the new system toplevel (when enough RAM is free) and runs:

   ```bash
   nix store diff-closures /run/current-system <new-toplevel>
   ```

4. Sends one or more desktop notifications listing **every** package line from that diff, e.g.:

   ```text
   Title: NixOS updates available (12 packages)
   Body:
   firefox: 128.0 → 129.0
   linux: 6.12.1 → 6.12.5
   gnome-shell: 47.1 → 47.2
   ```

   Large diffs are split across numbered notifications (`1/3`, `2/3`, …) so GNOME body limits never drop package names.

This tool **does not** run `nixos-rebuild switch`. Apply updates yourself (e.g. `bin/update/host`) when memory and time allow.

## Usage

```bash
# Defaults: flake=$HOME/.dotfiles/hosts/$(uname -n), current=/run/current-system
nixos-update-notifier

# Print package list only (no desktop notification)
nixos-update-notifier --no-notify

# Only check whether flake.lock would change (no build / no package list)
nixos-update-notifier --lock-only --no-notify

# Explicit host flake
nixos-update-notifier \
  --flake ~/.dotfiles/hosts/drakkar \
  --hostname drakkar
```

### Options / env

| Flag | Env | Default | Meaning |
|------|-----|---------|--------|
| `--flake` | `NIXOS_UPDATE_FLAKE` | `~/.dotfiles/hosts/<hostname>` | Host flake directory |
| `--hostname` | `NIXOS_UPDATE_HOSTNAME` | `uname -n` | `nixosConfigurations` attr |
| `--current-system` | `NIXOS_UPDATE_CURRENT` | `/run/current-system` | Closure to diff against |
| `--min-mem-mib` | `NIXOS_UPDATE_MIN_MEM_MIB` | `4096` | Skip build if free RAM below this |
| `--body-limit` | `NIXOS_UPDATE_BODY_LIMIT` | `900` | Max chars per notification body |
| `--no-notify` | — | off | Stdout only |
| `--lock-only` | — | off | Skip build + package diff |

If the lock would change but free memory is below `--min-mem-mib`, you get a notification that updates are pending (without a package list) so the build does not fight interactive sessions / OOM killers.

## Host install

`features/cli/nixos-update-notifier` (imported from `profiles/base.nix`):

- Installs the binary on PATH
- Enables a **user** systemd timer (~09:00 daily, persistent + random delay)
- Sets `NIXOS_UPDATE_*` for the host flake under `~/.dotfiles/hosts/<hostname>`

Requires a logged-in graphical session for notifications (session bus). Missed runs fire on next login when `Persistent=true`.

Host flakes must expose the path input:

```nix
nixos-update-notifier-src = {
  url = "path:../../rust/tools/nixos-update-notifier";
  flake = false;
};
```

The old root `features/nixos/auto-update` nightly switch is disabled (`enableAutoUpdate = false`): root cannot update a user-owned git flake, and automatic switch is unsafe under memory pressure.

## Develop / test

Standalone crate (own `Cargo.lock` for `buildRustPackage`):

```bash
cd rust/tools/nixos-update-notifier
cargo test
nix-build -E 'with import <nixpkgs> {}; callPackage ./. {}'
```

## Non-goals

- Auto `nixos-rebuild switch` / reboot
- GNOME Software–style update UI (Shell extensions are GJS-only; this is banner + tray text)
- Replacing `bin/update/host` or interactive rebuild workflows
