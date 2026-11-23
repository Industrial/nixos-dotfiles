# NixOS Dotfiles

[![CI - PR](https://github.com/Industrial/nixos-dotfiles/actions/workflows/pr.yml/badge.svg)](https://github.com/Industrial/nixos-dotfiles/actions/workflows/pr.yml)
[![CI - Main](https://github.com/Industrial/nixos-dotfiles/actions/workflows/main.yml/badge.svg)](https://github.com/Industrial/nixos-dotfiles/actions/workflows/main.yml)

The NixOS configuration for a four-machine fleet, in one flake. Software is split into
small **features** (plain NixOS modules), grouped into **profiles**, and composed per
**host**. There is no [Home Manager](https://github.com/nix-community/home-manager): user
configuration is written by the NixOS modules themselves.

Further reading: [`docs/README.md`](docs/README.md) indexes the ADRs, runbooks, principles
and security docs. The development environment is covered in
[`docs/development.md`](docs/development.md).

## Hosts

| Host | Role | Notes |
| --- | --- | --- |
| [**drakkar**](hosts/drakkar/) | Desktop workstation and gaming station (Gigabyte X870E, AMD) | Remote builder for the fleet; wired-only (WiFi driver blacklisted) |
| [**huginn**](hosts/huginn/) | Tablet ([StarLite 5](https://us.starlabs.systems/products/starlite), Intel N200) | Hibernation swapfile; Intel graphics |
| [**mimir**](hosts/mimir/) | Headless file server | `/data` btrfs RAID5 over NFS; Prometheus + Grafana; RustDesk relay; the only host with the STIG baseline |
| [**muninn**](hosts/muninn/) | Intel portable machine | Monitoring standby for mimir (Prometheus + Grafana) |

Every host has the same per-host docs: `INSTALL.md` (disk layout and reinstall) and
`DATA.md` (storage layout and where data belongs).

What every host shares, as of today:

- **Profiles** `base`, `communication`, `desktop`, `development`. drakkar and muninn add
  `ai`; drakkar adds `gaming`. `creative` and `crypto` exist but no host imports them.
- **Fleet features** `features/fleet/comin.nix` (pull convergence, [ADR-0002](docs/adr/0002-comin-pull-convergence.md))
  and `features/fleet/remote-access.nix` (Tailscale, SSH, operator keys, RustDesk client).
- **Remote builds**: mimir is the only build client
  (`features/fleet/nix-remote-builder-client.nix`); drakkar, huginn and muninn are builders
  (`features/fleet/nix-remote-builder-server.nix`). See
  [`docs/runbooks/nix-remote-build.md`](docs/runbooks/nix-remote-build.md).

The source of truth for all of this is `hosts/<host>/configuration.nix`; if this table and
that file disagree, the file wins.

## How the flake is built

```
flake.nix                       hosts = [drakkar huginn mimir muninn]
  └─ lib/mk-host.nix            nixosSystem per host; specialArgs = {inputs, settings}
       ├─ common/settings.nix   settings.{hostname, username = "tom", stateVersion, userdir, ...}
       └─ hosts/<host>/configuration.nix
            ├─ disko.nix, filesystems.nix, hardware.nix
            ├─ profiles/<name>.nix        imports a list of features
            │    └─ features/<category>/<feature>/default.nix
            └─ features/...               host-specific features, imported directly
```

- **Features** live in `features/<category>/` (20 categories: `ai`, `cli`, `nixos`,
  `programming`, `security`, `window-manager`, ...). A feature is a directory with a
  `default.nix` NixOS module, or a single loose module such as
  `features/fleet/comin.nix`. Composition is by path import: a feature is on for a host
  when some import chain reaches it, and there are no `enable` options. (An enable-option
  model is in progress; this section and [Adding things](#adding-things) change with it.)
- **Profiles** (`profiles/*.nix`) are import lists: `base` (every host; pulls in
  `cli-core`), `desktop` (pulls in `cli-desktop`), `development`, `communication`, `ai`,
  `gaming`, `creative`, `crypto`.
- **Hosts** import profiles plus any host-specific features, and their own hardware and
  disk modules.

The root flake also exports:

| Output | What it is |
| --- | --- |
| `nixosConfigurations.<host>` | the four hosts, plus `installer` |
| `deploy.nodes.<host>` | [deploy-rs](https://github.com/serokell/deploy-rs) nodes, driven by `bin/fleet` |
| `packages.x86_64-linux.installer-iso` | the install ISO (`bin/flash-installer` builds and writes it) |
| `stigReport.<host>` | per-host STIG compliance report ([runbook](docs/runbooks/stig-compliance.md)) |
| `checks.x86_64-linux` | deploy-rs schema checks plus one STIG VM test per verified control |

`hosts/<host>/flake.nix` is a shim that re-exports the root flake, so
`nixos-rebuild --flake .#<host>` also works from inside a host directory (the shims are
slated for removal). New work goes through the root flake.

## Adding things

Every `*.nix` file needs a colocated `*.assay.nix` suite (see [Tests](#tests-assay)), and
every feature must be reachable from some host. CI enforces both. The steps below are for
composition by path import, which is what `main` does today; they are the one place to
update when the enable-option model lands.

**A feature.** Create `features/<category>/<name>/default.nix` and
`features/<category>/<name>/default.assay.nix`, then add `../features/<category>/<name>`
to a profile's `imports` (or `../../features/...` to a host's).

**A profile.** Create `profiles/<name>.nix` (an `imports` list of features) and
`profiles/<name>.assay.nix`, then import `../../profiles/<name>.nix` from the hosts that
should carry it.

**A host.**

1. Create `hosts/<name>/` with `configuration.nix`, `disko.nix`, `filesystems.nix`,
   `hardware.nix`, each with its `*.assay.nix`, plus `INSTALL.md` and `DATA.md`. Copy the
   closest existing host.
2. Add the name to `hosts` in `flake.nix`. That alone creates its `nixosConfigurations`,
   `deploy.nodes` and `stigReport` entries.
3. Add it to the other host lists, which are not derived from `flake.nix`:
   `HOSTS` in `bin/fleet`, `VALID_HOSTS` in `installer/install-nixos.sh`, `fleetHosts`
   and `operatorPubKeys` in `features/fleet/operator-ssh.nix`, and the `check` matrix in
   `.github/workflows/*.yml` together with the host `case` in
   `.github/actions/check/action.yml`.
4. Install it: `hosts/<name>/INSTALL.md`, starting from `bin/flash-installer`.

## Tests (assay)

Tests are [Assay](https://github.com/Industrial/assay) suites: `*.assay.nix` files beside
the module they cover, written with the claim DSL in
[`common/assay/`](common/assay/README.md).

```bash
bin/with-devenv assay run .                  # every suite in the repo
bin/with-devenv assay run features/fleet     # one directory
bin/assay-coverage-check                     # every in-scope *.nix has a colocated suite
bin/ci/feature-reachability                  # every feature reaches a host closure
```

`moon run :test` runs the same `assay run .` through moon. Exceptions to the coverage
check are listed in `common/assay/coverage-allowlist.txt`; features deliberately parked
outside every host are listed in `common/ci/feature-reachability-baseline.txt`.

## CI

Two GitHub Actions workflows run the same job set: `pr.yml` on pull requests to `main`,
`main.yml` on pushes to `main`. Each job is a composite action in `.github/actions/`,
most of them a thin wrapper around a `bin/ci/*` script you can run locally.

| Job | Runs | Checks |
| --- | --- | --- |
| `format` | `bin/ci/lint` | `treefmt --config-file treefmt.ci.toml` makes no change |
| `deadnix` | `bin/ci/deadnix` | no unused Nix bindings |
| `assay` | `bin/ci/assay` | all suites pass, then `bin/assay-coverage-check` |
| `feature-reachability` | `bin/ci/feature-reachability` | no feature outside every host closure |
| `lint-fetch-pins` | `bin/ci/lint-fetch-pins` | no fetcher under `features/` points at a moving target (`latest`, `master`) |
| `shell-budget` | `bin/ci/shell-budget` | shell startup within budget ([terminal runbook](docs/runbooks/terminal.md)) |
| `stig` | `bin/ci/stig` | STIG reports build; CAT I gate. `main.yml` also boots the VM tests |
| `clamav`, `lynis` | `bin/ci/clamav`, `bin/ci/lynis` | malware and hardening scans |
| `cargo-clippy`, `cargo-test`, `cargo-nix-drift` | inline | the Rust tools under `rust/` |
| `check (<host>)` | `.github/actions/check` | `nix flake check`, then `nix build --dry-run` of the host's toplevel |

`check` covers drakkar, huginn and mimir. **muninn is not in the matrix**, so nothing in
CI evaluates it.

## Day-to-day

```bash
bin/update/system          # nixos-rebuild switch --flake .#$(hostname), then feature link scripts
bin/update/host            # same as bin/update/system, logged to logs/update-host
bin/update/flake           # vbump run --rev origin/main: one lock-bump PR per input
bin/update/channels        # nix-channel --update
bin/update/profiles        # nix profile upgrade --all

bin/fleet status           # SSH reachability of all four hosts
bin/fleet deploy <host>    # deploy-rs push; see docs/runbooks/fleet-deploy.md

bin/generations/list                      # system generations, every profile, with diffs (vgen list)
bin/generations/rollback system-<N>-link  # switch to a generation (argument required)
bin/generations/delete                    # keep the newest 2 per system profile (vgen prune --keep 2)
sudo vgen pin <N> [--profile comin]       # keep a generation through pruning and GC
bin/delete/collectgarbage                 # vgc run --delete-old (nix-collect-garbage -d)
```

comin pulls `origin/main` on every host every 300 seconds, so an unpushed local switch is
reverted within five minutes. Push first; see
[`docs/runbooks/fleet-deploy.md`](docs/runbooks/fleet-deploy.md).

The login shell (Nushell) is set declaratively by `users.users.<name>.shell`; see
[ADR-0005](docs/adr/0005-shell-strategy.md) and the
[terminal runbook](docs/runbooks/terminal.md).

## Development

Toolchain commands run through `bin/with-devenv <cmd>`, which gives the command the devenv
shell's packages and environment without entering `devenv shell`. Details, including the
git hooks, are in [`docs/development.md`](docs/development.md) and
[`AGENTS.md`](AGENTS.md).

## License

Released into the public domain. See [LICENSE](LICENSE).
