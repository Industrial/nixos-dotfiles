# Development: fresh clone to first PR

Everything here goes through one entry point, `bin/dev`. Run it with no
arguments to list the commands. It dispatches to tooling the repo already has:
CI's jobs are `bin/ci/*`, deploys are `bin/fleet`, updates are `bin/update/*`,
and the moon tasks in `moon.yml` call back into `bin/dev`. It doesn't replace
any of them.

```bash
bin/dev                 # the command list
bin/dev doctor          # what is missing on this machine
bin/dev check           # what CI will say, minus the host builds
```

## Prerequisites

| Tool | Why | Where from |
|------|-----|------------|
| Nix, with `nix-command flakes` enabled | everything | <https://nixos.org/download>; on NixOS hosts of this fleet it is already set |
| git | it is a repo | host |
| [devenv](https://devenv.sh) | the toolchain: assay, treefmt, moon, jq, python3, formatters | host (`features/programming/devenv` on fleet machines) |
| direnv (optional) | loads the toolchain on `cd` | host (`features/cli/direnv`) |
| gh (optional) | opening PRs from the CLI | host, or the devenv toolchain |

`bin/dev doctor` checks all of these and prints a line per problem.

You don't need to enter `devenv shell`. Any command that needs the toolchain
re-runs itself through `bin/with-devenv`, which runs a command with the
shell's packages and environment *without* entering the shell. When neither
the toolchain nor devenv is available, the command stops and names the missing
tool, rather than failing somewhere inside a CI script:

```
bin/dev: missing on PATH: assay
  They come from the devenv toolchain, and devenv is not installed.
  Install devenv (https://devenv.sh), then either 'direnv allow' in the repo
  or prefix the command: bin/with-devenv bin/dev test nushell
```

### Why the shell isn't entered for you

Entering the devenv shell used to run every git hook (`prek run -a`). Hooks
that entered the shell themselves then recursed: 16+ concurrent prek processes
on 2026-11-18, and prek's tree-wide stash reverted 153 dirty files. Since then:

- shell entry *installs* the git hooks but never runs them
  (`nix/devenv-modules/no-hooks-on-shell-entry.nix`);
- hooks and scripts reach the toolchain through `bin/with-devenv`;
- `devenv.assay.nix` asserts that `devenv.nix` adds no `enterShell` work, no
  task wiring, and only commit/push-stage hooks that go through `with-devenv`.

Please don't add shell-entry hooks back.

## 1. Clone and orient

```bash
git clone git@github.com:Industrial/nixos-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bin/dev doctor
direnv allow            # optional: puts `dev`, assay, treefmt... on PATH on cd
```

The first toolchain command in a fresh clone is slow, because `bin/with-devenv`
falls back to `devenv shell --` until the shell has been entered once and has
linked `.devenv/with-devenv`. After that it's fast. A git worktree is a fresh
clone in this sense.

Layout:

| Path | What lives there |
|------|------------------|
| `flake.nix` | the fleet flake: `nixosConfigurations.{drakkar,huginn,mimir,muninn,installer}`, deploy-rs nodes, checks |
| `hosts/<host>/` | per-machine configuration |
| `profiles/*.nix` | bundles of features a host imports |
| `features/<area>/<name>/` | one module per feature, each with a colocated `*.assay.nix` suite |
| `common/` | shared settings, the assay DSL (`common/assay/`), CI baselines (`common/ci/`) |
| `bin/` | `bin/dev`, CI job scripts (`bin/ci/*`), fleet and update tooling |
| `docs/` | ADRs, runbooks, this file |

`bin/dev hosts` lists the hosts the flake defines.

## 2. Make a change

A change is usually a feature module plus its suite:

```
features/cli/navi/default.nix         # the module
features/cli/navi/default.assay.nix   # its claims
```

Every in-scope `*.nix` needs a colocated `*.assay.nix`. `bin/assay-coverage-check`
enforces that, and so does CI. Prefer claims about evaluated config, for example
"this option ends up set to X", over regexes on the source text. A feature also
has to be imported by some host closure, or `feature-reachability` fails.

### Fast paths

| You want | Run | Takes |
|----------|-----|-------|
| one feature's suites | `bin/dev test nushell` (or `cli/nushell`, or a path) | about a second |
| one suite file | `bin/dev test devenv.assay.nix` | under a second |
| every suite, as CI runs it | `bin/dev test` | minutes |
| one host evaluates | `bin/dev eval mimir` (no host: this machine) | ~20 s, a few GB RAM |
| one host builds | `bin/dev build mimir` | long; not part of any default |
| poke at the flake | `bin/dev repl` | |

`bin/dev eval <host>` prints the system derivation path without building
anything. It is the cheap way to learn "does my change still evaluate on that
host". Avoid full host builds on a shared or memory-constrained machine. CI's
`check (<host>)` jobs do them for you.

## 3. Before you push

```bash
bin/dev check            # same as: bin/dev pre-push, moon run dotfiles:check
bin/dev check -n         # just print the plan
```

`check` runs the PR workflow's cheap jobs, using the scripts CI itself runs,
and prints a pass/fail summary with a log per step under `.tmp/dev/check/`:

| Step | CI job (`.github/workflows/pr.yml`) | Script |
|------|-------------------------------------|--------|
| `format` | `format` | `bin/ci/lint`, over the files changed against the merge base (`--format-all`: the whole tree, as CI) |
| `deadnix` | `deadnix` | `bin/ci/deadnix` |
| `feature-reachability` | `feature-reachability` | `bin/ci/feature-reachability` |
| `lint-fetch-pins` | `lint-fetch-pins` | `bin/ci/lint-fetch-pins` |
| `assay` | `assay` | `bin/ci/assay` (suites + coverage) |
| `bin-dev-selftest` | (none yet) | `bin/dev.d/test.sh` |
| `cargo-clippy`, `cargo-test` | same names | only when `rust/` changed, or `--rust` |
| `eval-<host>` | `check (<host>)`, eval half | only with `--host <h>` or `--hosts` |
| `flake-check` | `check (<host>)`, `nix flake check` | only with `--flake-check` |

By default it builds no host and evaluates none. Add `--host mimir` for the
host your change touches, or `--hosts` for all three CI hosts, evaluated one at
a time. `--only a,b`, `--skip a,b` and `--fail-fast` do what they say.

Left to CI: `clamav`, `lynis`, `stig`, `shell-budget` and the `check (<host>)`
dry-run builds. Each of these has a `bin/ci/<name>` you can run by hand. Run
`bin/ci/shell-budget` when you touch `features/cli/nushell` or
`features/cli/shell-init`.

The format step rewrites the files it would fail on, as `treefmt` does, so
check `git diff` afterwards. `bin/dev format` formats on purpose.

**Main may already be red.** When a step fails, compare it with main's latest
run (`gh run list -R Industrial/nixos-dotfiles -b main`) before you treat the
failure as yours. A new error inside an already-red job still counts.

## 4. Git hooks

Installed when the devenv shell is first entered. They run on git events,
never on shell entry:

| Hook | Runs | Skip |
|------|------|------|
| pre-commit | `moon run dotfiles:test --affected` | `git commit --no-verify` |
| pre-push | `moon run dotfiles:test`, then deepsec on the pushed range (`bin/git-hooks/deepsec-pre-push`) | `DEEPSEC_PRE_PUSH_SKIP=1` for deepsec; `--no-verify` for all |

prek stashes unstaged changes across the *whole tree* while a hook runs. If
another process is editing the tree at the same time, commit just your path
with `git commit --only <path>`. To recover stashed work, look in
`.devenv/state/prek/patches/`.

## 5. Commit and open the PR

- Branch off `main`. Make one logical change per commit, split along revert
  boundaries.
- Commit subjects follow `type(scope): what changed`, for example
  `fix(bin): ...` or `feat(programming): ...`. See `git log`.
- Push and open the PR against `main`:

  ```bash
  git push -u origin HEAD
  gh pr create --base main --fill
  gh pr checks --watch
  ```

- In the PR body, say which CI failures were already on main and which, if
  any, are new.

## Task map

| Task | bin/dev | moon | inside the shell |
|------|---------|------|------------------|
| list commands | `bin/dev` | | `dev` |
| CI mirror | `bin/dev check` | `moon run dotfiles:check` | `dev check` |
| tests | `bin/dev test [target]` | `moon run dotfiles:test [-- target]` | `dev test` |
| format | `bin/dev format` | `moon run dotfiles:format` | `format`, `dev format` |
| lint | `bin/dev lint` | `moon run dotfiles:lint` | `dev lint` |
| host eval | `bin/dev eval <host>` | `moon run dotfiles:eval -- <host>` | `dev eval <host>` |
| host build | `bin/dev build <host>` | | |
| deploy | `bin/dev deploy <host\|all>` (`bin/fleet`, see `docs/runbooks/fleet-deploy.md`) | | |
| update | `bin/dev update [flake\|channels\|system\|...]` | | |
| STIG VM tests | `bin/stig-vm-test` | `moon run dotfiles:stig-vm-test` | |

## Troubleshooting

- **`missing on PATH: <tool>` after the re-run through `bin/with-devenv`.** The
  `.devenv/with-devenv` wrapper predates a `devenv.nix` change. Enter the shell
  once (`direnv reload`, or `devenv shell` and exit) to rebuild it.
- **`bin/with-devenv: cannot supply the devenv toolchain`.** devenv isn't
  installed and this checkout has no `.devenv/with-devenv` yet. Install devenv.
- **A hook seems to run on `cd` or on shell entry.** It shouldn't. Run
  `bin/dev test devenv.assay.nix`, and look at
  `nix/devenv-modules/no-hooks-on-shell-entry.nix`.
- **`bin/dev eval` is slow the first time.** It fetches the flake inputs.
  After that the evaluation cache makes it about 20 s per host.
