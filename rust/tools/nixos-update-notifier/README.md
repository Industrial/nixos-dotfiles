# nixos-update-notifier

Tells the operator what an update is waiting on (see `docs/runbooks/updates.md`):

- an **open lock-bump PR** from `.github/workflows/update-flake-lock.yml`, awaiting review:
  the legacy single PR on `update/flake-lock`, or any of vbump's per-input PRs on
  `update/flake-lock-<input>` (unauthenticated GitHub API, public repo: one
  `GET /repos/{repo}/pulls?state=open&per_page=100`, filtered on `head.ref`, and only PRs whose
  head is this repository, not a fork). While one is open the local build below is skipped,
  since the PR body already carries the per-host diff;
- a **pending reboot**: `kernel`, `initrd` or `kernel-modules` of `/run/current-system` differ
  from `/run/booted-system` (comin switched, but nothing reboots by itself);
- otherwise, whether upstream inputs moved, with **the exact packages** that would change.

Uses the session D-Bus (`org.freedesktop.Notifications`) so GNOME shows a normal banner and tray entry — same channel as `notify-send`.

On a headless host (no notification server answers, `org.freedesktop.DBus.Error.ServiceUnknown`,
or no session bus at all) the notice goes to stderr, so the journal, after the line
`no notification server reachable (…); logging the notice instead`, and the run still exits 0.
Any other send error, and every eval, GitHub, build or vdiff error, exits 1.

## What it does (upstream check)

1. Runs `nix flake update --output-lock-file` into a temp lock (does **not** modify your repo `flake.lock`).
2. If the lock is unchanged → exits quietly (“up to date”).
3. If the lock would change → builds the new system toplevel (when enough RAM is free) and runs:

   ```bash
   vdiff --json /run/current-system <new-toplevel>
   ```

   [vdiff](../vdiff/README.md) reads the store database directly; the notifier reads its
   `--json` report (schema 1). vdiff is a runtime dependency on an absolute store path: the
   package's wrapper sets `NIXOS_UPDATE_VDIFF`.

4. Sends one or more desktop notifications listing **every** package line from that diff:
   version changes, then added packages, then removed ones (vdiff's `selectionChanged`
   entries, same versions on both sides, are not updates and are left out). `∅` is a side
   the package is not on, `ε` a store path with no version, as in `nix store diff-closures`:

   ```text
   Title: NixOS updates available (9 packages)
   Body:
   voltaic: 0.2.1 → 0.3.0
   vci: ∅ → 0.1.0
   vswitch: ∅ → ε, 0.1.0
   command-not-found: ε → ∅
   ```

   A downgrade ends in ` (downgrade)`.

   **Rollback:** `--differ nix` (`NIXOS_UPDATE_DIFFER=nix`; on a host,
   `features.cli.nixos-update-notifier.differ = "nix";`) diffs with
   `nix store diff-closures` again, as before GH-207.

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
| `--lock-branch` | `NIXOS_UPDATE_LOCK_BRANCH` | `update/flake-lock` | Lock-bump branch: the workflow's single PR branch, and the prefix of vbump's `<branch>-<input>` |
| `--differ` | `NIXOS_UPDATE_DIFFER` | `vdiff` | `vdiff` (`vdiff --json`) or `nix` (`nix store diff-closures`, the rollback) |
| `--vdiff` | `NIXOS_UPDATE_VDIFF` | `vdiff` (the package: vdiff's store path) | The vdiff binary |
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

The feature builds the crate with `pkgs.callPackage ../../../rust/tools/nixos-update-notifier/default.nix {}`
and a `lib.fileset` source, like the other crates (until GH-207 it was the
`nixos-update-notifier-src` path input of the root flake).

The old root nightly switch in `features/nixos/auto-update` is gone; that feature now only asserts `system.autoUpgrade` stays off (comin is the single unattended activator, ADR-0006).

## Develop / test

Standalone crate (own `Cargo.lock` for `buildRustPackage`):

```bash
cd rust/tools/nixos-update-notifier
cargo test
bash bin/ci/cargo-standalone package nixos-update-notifier   # from the repo root
```

The vdiff parser's tests read real `vdiff --json` captures of drakkar's system generations
(`tests/fixtures/vdiff-drakkar-<old>-<new>.json`, `vdiff --json
/nix/var/nix/profiles/system-<old>-link /nix/var/nix/profiles/system-<new>-link`).

## Non-goals

- Auto `nixos-rebuild switch` / reboot
- GNOME Software–style update UI (Shell extensions are GJS-only; this is banner + tray text)
- Replacing `bin/update/host` or interactive rebuild workflows
