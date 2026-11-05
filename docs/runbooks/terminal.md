# Terminal runbook

The shell, the multiplexer and the keymap: what loads, in what order, and what to reach for
when one of them is in the way.

> **Nushell is the login shell** (ADR-0005) and **zellij is the surface** it runs in. Neither
> is configured through home-manager — every piece is a NixOS feature under `features/cli/`,
> so a change is a `nixos-rebuild` away rather than an edit away. The one deliberate
> exception: `~/.config/nushell/{env,config,havamal}.nu` are symlinks into the checkout
> (`features/cli/nushell/default.nix`), so editing those applies on the next shell.

## The surface

| Layer | Feature | Note |
|---|---|---|
| Login shell | `features/cli/nushell` | `users.users.<name>.shell`, one writer (ADR-0005) |
| Generated init | `features/cli/shell-init` | writes `$nu.data-dir/vendor/autoload` at build time |
| Prompt | `features/cli/starship` | `starship.toml`, declared |
| Multiplexer | `features/cli/zellij` | `clear-defaults=true` keymap, four generated layouts |
| Terminals | `features/window-manager/{alacritty,ghostty}` | |
| Fallback shell | `features/cli/fish` | on `/etc/shells`, not in `/etc/passwd` |

A bare `zellij` gets zellij's own single pane (`default_layout "default"`). The dashboards are
opt-in:

```bash
zellij --layout system   # six-tab operations dashboard
zellij --layout dev      # editor | shell / lazygit, inherits $PWD
zellij --layout agents   # scratch / agent / http / sql, rooted at the checkout
zellij --layout data     # slumber beside lazysql, inherits $PWD
```

## Startup: what loads, in what order

Measured on nushell 0.116.1:

```
env.nu                                  features/cli/nushell/env.nu   (symlinked)
config.nu                               features/cli/nushell/config.nu (symlinked)
$nu.data-dir/vendor/autoload/
  00-nixos-env.nu                       environment.sessionVariables, generated
  10-starship.nu                        starship init nu, run at build time
  20-zoxide.nu                          zoxide init nushell --cmd cd
  30-carapace.nu                        carapace _carapace nushell
  40-atuin.nu                           atuin init nu
  52-git-completions.nu                 nu_scripts, copied from the pinned flake input
  53-make-completions.nu
  54-nix-completions.nu
```

Three things about that order are load-bearing:

1. **`vendor/autoload` runs _after_ `config.nu`, not before.** Anything in `config.nu` that
   expects the prompt, `cd`, the external completer or history to exist is reading a shell
   that does not have them yet.
2. **The whole chain is REPL-only.** `nu -c '…'` and `nu script.nu` load *none* of it — not
   the autoload directory, and as of 0.116 not `env.nu` or `config.nu` either. Verified:

   ```bash
   # a def in config.nu, a def in an autoload file: neither resolves
   nu -c 'cfgprobe'   # error: neither a Nushell built-in or a known external command
   nu script.nu       # same
   ```

   So a non-interactive `nu` sees only the process environment it inherited. Variables a
   script needs come from `environment.sessionVariables`, never from the repo's `.nu` files.
3. **Which is why the startup budget is not measured with `nu -c exit`.** That command would
   report a number with none of the above in it. `bin/ci/shell-budget` replays the chain
   explicitly instead; see below.

The autoload directory is one symlink into the store, not a file-by-file copy, so dropping a
hook takes its file with it rather than leaving a stale one that every shell keeps sourcing.

```bash
ls -l ~/.local/share/nushell/vendor/autoload   # -> /nix/store/…-nushell-vendor-autoload
```

Prefix numbers select order, not membership. To drop a hook or take a completer the default
set leaves out:

```nix
cli.shellInit.hooks = ["env" "starship"];            # default: all five
cli.shellInit.completers = ["git" "make" "nix" "cargo"];  # default: git make nix
```

## The zellij keymap

`config.kdl` declares `keybinds clear-defaults=true`. Every zellij default is therefore
**gone**, including the ones zellij's own help screen and its upstream manual describe — the
fleet binds `Alt`-prefixed modes where stock zellij binds `Ctrl`. Reading upstream docs for
this fleet's keys will mislead you.

The authoritative keymap is **generated from `config.kdl`**, never transcribed:

| Where | What |
|---|---|
| `features/cli/zellij/etc/zellij/config.kdl` | the single source of truth |
| `features/cli/zellij/keymap-card.nix` | the parser; evaluates to markdown |
| `/etc/zellij/keymap.md` | the card, on every host carrying the feature |
| `~/.config/zellij/keymap.md` | symlink to the above, beside `config.kdl` |

```bash
bat ~/.config/zellij/keymap.md                             # on a host
nix eval --raw -f features/cli/zellij/keymap-card.nix      # from a bare checkout, no build
```

The generator is `builtins`-only and takes no arguments precisely so that second line works
without the module system. `features/cli/zellij/keymap-card.assay.nix` re-derives the mode,
block and bind counts from `config.kdl` with regexes the generator does not share, so a
parser that started ignoring its input fails the suite rather than shipping a confident card
that disagrees with the keymap. The card is **not** committed anywhere: a committed copy of
generated content drifts from its source, which is the same reason the four layouts and the
`vendor/autoload` files are generated too.

There is **no key bound to open the card**. Doing that means adding a `bind` to `config.kdl`,
and `config.kdl` is the generator's input — out of scope for the leaf that added the
generator. The one-line change, for whoever wants it, goes in `shared_except "locked"`:

```kdl
bind "Alt ?" { Run "bat" "--style" "plain" "/etc/zellij/keymap.md"; floating true; }
```

It would show up in the card by itself, which is the point.

## Startup budget

`bin/ci/shell-budget` is the gate, wired into CI. It measures the **ratio** of replayed
interactive startup to the `nu -n -c ""` floor from one `hyperfine` run on one machine,
rather than a wall-clock threshold, because a shared runner is slower and noisier than the
machine a millisecond budget would have been written on.

Measured on drakkar, 2026-11-05, nushell 0.116.1:

| stage | median |
|---|---|
| floor, `nu -n -c ""` | 8.3 ms |
| `+ env.nu + config.nu` | 11.6 ms |
| `+` the five generated hooks (00–40) | 21.6 ms |
| `+` the three nu_scripts completers (52–54) | 28.1 ms = **3.39x floor** |

Budget: **4.0x**, which at drakkar's floor is ~33 ms — tighter than the 35 ms the budget was
originally written as. Headroom is about one more completer; `cargo` (+1.3 ms) and `docker`
(+1.6 ms) are selectable and left off for exactly that reason.

```bash
bin/ci/shell-budget                                  # the gate
SHELL_BUDGET_AUTOLOAD=/path/to/dir bin/ci/shell-budget   # price a completer before adding it
```

`cli.shellInit.completers` is the knob meant to be turned down. A hook is not.

## Adding a tool

Three artifacts, always, in one commit:

1. `features/<area>/<tool>/default.nix` — the feature.
2. `features/<area>/<tool>/default.assay.nix` — a **colocated** suite. `foo.nix` pairs with
   `foo.assay.nix`; `default.nix` pairs with `default.assay.nix` and nothing else.
3. An import line in `profiles/cli-core.nix` (every host, including an ssh-only server) or
   `profiles/cli-desktop.nix` (graphical hosts only).

Each of the three has a gate behind it:

```bash
bin/assay-coverage-check      # (2): any in-scope .nix without a colocated suite fails
bin/ci/feature-reachability   # (3): a feature no profile imports fails
devenv shell -- assay run .   # the suites themselves
bin/ci/deadnix                # unused bindings
bin/ci/lint-fetch-pins        # no fetch* resolving a moving target
alejandra --check .           # formatting
```

Skipping (3) is the common failure and it is silent: an unimported feature builds, evaluates
and ships nothing. `common/ci/feature-reachability-baseline.txt` ratchets this — it carries
55 pre-existing orphans so the gate fails only on *newly* orphaned directories. Do not add
to it for a new feature; wire the import instead.

Two conventions worth copying rather than rediscovering:

- **Generate, do not commit, anything a tool can print.** `features/cli/shell-init` runs
  `starship init nu` and friends at build time, against the exact store path the host
  installs. A committed copy drifts from the binary it came from the moment either moves.
- **Name activation scripts after what they do.** `system.activationScripts.linkZellijConfig`,
  not `linkFile` — see the defect table below for what the generic name cost.

## Escape hatches

| Hatch | Effect |
|---|---|
| `Ctrl-g` | zellij **locked mode**: every key passes through to the pane, for a nested nvim, lazygit or inner zellij. `Ctrl-g` again returns to normal. Every other `shared_except` block excludes `locked`, so pass-through is total. |
| `ZELLIJ_AUTO_ATTACH=0` | `config.nu` does not auto-attach or auto-start a session. This is what a startup benchmark wants, and what you want when debugging the shell itself. |
| `HAVAMAL=0` | no greeting stanza on start (also skipped automatically inside a zellij pane, so you get one stanza per session rather than one per pane). |
| `DEEPSEC_PRE_PUSH_SKIP=1 git push` | skips the deepsec pre-push security gate. |
| `nu -n` | a shell with none of the above: no `env.nu`, no `config.nu`, no autoload. The floor `bin/ci/shell-budget` measures against. |

## Known defects — recorded, not fixed

Verified live on this branch and deliberately left alone, so they are not rediscovered as
novel. Each one is a separate change with its own blast radius.

| Where | Defect |
|---|---|
| `common/settings.nix:25` | `useremail` interpolates `system`, not `hostname`: `tom@x86_64-linux.local`. Consumed by `features/programming/git` (`user.email`) and `features/cli/create-ssh-key` (the key comment). |
| `.github/workflows/pr.yml` | the `check` matrix is `[drakkar, huginn, mimir]` — **muninn is omitted**, and `.github/actions/check/action.yml` hard-rejects any host outside those three, so adding it to the matrix alone is not enough. |
| `.github/actions/vulnix/` | exists, is wired to no workflow job in any file under `.github/`. |
| `bin/git-hooks/deepsec-pre-push:20-22` | **`.deepsec/` does not exist.** The hook returns 0 when `.deepsec/deepsec.config.ts` is missing, so the pre-push security gate AGENTS.md documents is a silent no-op on every push. |
| `features/programming/git/default.nix:75` | `[core] mergeoptions = --no-edit` has been inert its whole life — git reads `merge.mergeoptions`, not `core.mergeoptions`. Pinned as-is by `mergeoptionsSurvive`. |
| `bin/generations/rollback:7` | `PREVIOUS_GENERATION="$@"` expands unquoted into a scalar, and the line that computed a default is commented out directly above it. The script is broken for its documented no-argument use. |
| `features/cli/nushell/config.nu:89` | `def p` lacks `--env`, so it cannot move the caller's directory — and it `cd`s to `~/projects`, which does not exist on drakkar. Outside the REPL `p` is a different command entirely: `/run/current-system/sw/bin/p` runs pnpm. |
| `features/cli/nushell/QUICKREF.md` | stale: documents `Ctrl-R` as fzf (atuin owns history now), `p`/`~/projects`, and none of the autoload chain above. |
| `features/window-manager/alacritty/default.nix:10` | claims the generic activation-script name `linkFile`. Four features have had to work around the collision. |
| `features/cli/zellij` | **inside zellij no terminal gets kitty graphics or sixel.** yazi's probe resolves at most `kitty-graphics-old` and then drops even that on detecting a multiplexer, so image previews do not work in a pane — under Ghostty too. Not a layout bug. |
| `features/cli/cheatsheet/README.md` | carries a recommendation to delete the feature, with the exact two-line diff. One leaf cannot land it: `profiles/cli-core.nix` is outside the feature and a dangling import breaks every host. |
| repo-wide | ~60 feature directories are reachable from no profile, ~30 of them commented out in a profile; 55 are baselined in `common/ci/feature-reachability-baseline.txt`. |
| `features/cli/zellij/etc/zellij/config.kdl` | the `system` dashboard has **20 content panes, not 17**. Its own comment, the assay comments and the mission plan all say seventeen. Count: txt 2 + sys 3 + net 4 + dsk 4 + mda 4 + cfg 3. |
| `features/cli/zellij/etc/zellij/config.kdl` | **`move` mode cannot be entered.** It declares seven binds, but `shared_except "move" "locked"` is commented out and `Alt h` — the key it would have used — is bound to `MoveFocusOrTab "Left"` in `shared_except "locked"`. Nothing switches to it. Found by the generated card, which lists `move` as a block with no entry key; pinned by `moveModeIsUnreachable`. |

## Related docs

- ADR: `docs/adr/0005-shell-strategy.md` — Nushell as login shell, fish as fallback, the
  single-writer rule, and the measurements the budget above descends from
- ADR: `docs/adr/0003-kernel-hardening-single-source.md` clause 4 — `users.defaultUserShell`
  stays unset
- `features/cli/nushell/README.md`, `features/cli/zellij` module header
- Deploying a change: `docs/runbooks/fleet-deploy.md`
