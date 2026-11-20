# nixos-update-notifier

Tells the operator what an update is waiting on (see `docs/runbooks/updates.md`):

- an **open lock-bump PR** from `.github/workflows/update-flake-lock.yml`, awaiting review
  (unauthenticated GitHub API, public repo; while one is open the local build below is skipped,
  since the PR body already carries the per-host diff);
- a **pending reboot**: `kernel`, `initrd` or `kernel-modules` of `/run/current-system` differ
  from `/run/booted-system` (comin switched, but nothing reboots by itself);
- otherwise, whether upstream inputs moved, with **the exact packages** that would change.

Uses the session D-Bus (`org.freedesktop.Notifications`) so GNOME shows a normal banner and tray entry — same channel as `notify-send`.

## What it does (upstream check)

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

This tool **does not** switch, merge or reboot. Updates reach hosts only through a merged lock-bump PR, which comin applies (ADR-0006).

## Usage

```bash
# Defaults: flake=$HOME/.dotfiles (root flake), current=/run/current-system
nixos-update-notifier

# Print package list only (no desktop notification)
nixos-update-notifier --no-notify

# Only check whether flake.lock would change (no build / no package list)
nixos-update-notifier --lock-only --no-notify

# Explicit flake + host
nixos-update-notifier \
  --flake ~/.dotfiles \
  --hostname drakkar
```

### Options / env

| Flag | Env | Default | Meaning |
|------|-----|---------|--------|
| `--flake` | `NIXOS_UPDATE_FLAKE` | `~/.dotfiles` | Root flake directory |
| `--hostname` | `NIXOS_UPDATE_HOSTNAME` | `uname -n` | `nixosConfigurations` attr |
| `--current-system` | `NIXOS_UPDATE_CURRENT` | `/run/current-system` | Closure to diff against |
| `--booted-system` | `NIXOS_UPDATE_BOOTED` | `/run/booted-system` | Compared with current to detect a pending reboot |
| `--github-repo` | `NIXOS_UPDATE_GITHUB_REPO` | empty (off) | `owner/name` whose open lock-bump PRs to report |
| `--lock-branch` | `NIXOS_UPDATE_LOCK_BRANCH` | `update/flake-lock` | Branch the workflow opens its PR from |
| `--min-mem-mib` | `NIXOS_UPDATE_MIN_MEM_MIB` | `4096` | Skip build if free RAM below this |
| `--body-limit` | `NIXOS_UPDATE_BODY_LIMIT` | `900` | Max chars per notification body |
| `--no-notify` | — | off | Stdout only |
| `--lock-only` | — | off | Skip build + package diff |

If the lock would change but free memory is below `--min-mem-mib`, you get a notification that updates are pending (without a package list) so the build does not fight interactive sessions / OOM killers.

## Host install

`features/cli/nixos-update-notifier` (imported from `profiles/cli-desktop.nix`):

- Installs the binary on PATH
- Enables a **user** systemd timer (~09:00 daily, persistent + random delay)
- Sets `NIXOS_UPDATE_*` for the root flake `~/.dotfiles`, this host, and the repo/branch of the lock-bump PR

Requires a logged-in graphical session for notifications (session bus). Missed runs fire on next login when `Persistent=true`.

The root `flake.nix` exposes the source as a path input (already present):

```nix
nixos-update-notifier-src = {
  url = "path:./rust/tools/nixos-update-notifier";
  flake = false;
};
```

The old root nightly switch in `features/nixos/auto-update` is gone; that feature now only asserts `system.autoUpgrade` stays off (comin is the single unattended activator, ADR-0006).

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
