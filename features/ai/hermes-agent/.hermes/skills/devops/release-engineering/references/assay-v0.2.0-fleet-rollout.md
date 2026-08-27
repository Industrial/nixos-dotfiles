# Assay v0.2.0 fleet rollout — 2026-08-23 (session record)

User instruction: "Look everywhere in ~/.dotfiles and /data/Code for where we use
assay and upgrade it to the latest version. Leave everything uncommitted."

## Consumer inventory (4 repos, 3 pin mechanisms)

| Location | Mechanism | Update applied |
|---|---|---|
| `~/.dotfiles/flake.nix` + `flake.lock` | flake input | `nix flake lock --update-input assay` → `ccf69c1 → d02232a` |
| `~/.dotfiles/devenv.yaml` + `devenv.lock` | devenv input | `devenv update assay` (scoped) |
| `~/.dotfiles/bin/ci/assay` | wrapper reading rev from devenv.lock via jq | auto-follows, no edit |
| test-loco-webapp `.cursor/nix/features/program-assay.nix` | pinned version + tarball SRI (fetchurl of GH release) | `0.1.0→0.2.0` + new SRI |
| solana-yield-optimizer same file | identical copy | same |
| idclear/monorepo same file | identical copy | same |
| assay repo `contrib/cursor-setup/program-assay.nix` + own `.cursor/nix/` copy | upstream template, wrapper-style (`releaseHash = null`, `nix run github:…/v${version}`) | default version bump only — deliberately NO SRI |

Key structural fact: the three consumer copies were byte-identical (verified by
diff before editing); the two template copies differ from consumers (null hash).
The feature module supports two install modes: pinned-release fetchurl (needs
SRI) vs nix-run wrapper (no hash).

## New pin values

- version: `0.2.0`
- rev: `d02232ab31ab4687891a64aed9cb193c5d3800dd`
- SRI: `sha256-qOHMVV+OLq18TlhJEpwS5/qdgQMgcxAkJheJY1mU38g=`
  (computed: download v0.2.0 `assay-x86_64-unknown-linux-gnu.tar.gz`,
  `nix hash file --sri --type sha256 <tarball>`; note `hash-file` is the
  deprecated alias)

## Scope incident (why scoped updates matter)

First attempt used bare `devenv update` → moved 5 inputs in devenv.lock
(assay + devenv itself + nixpkgs-src + nixpkgs-unstable + rust-analyzer-src).
Fix: `git checkout devenv.lock && devenv update assay`. Final diff proof:
exactly one changed rev per lockfile.

## Functional proof matrix (v0.2.0 binary, `assay run` per repo's suites)

| Repo/suite | v0.2.0 | v0.1.0 control |
|---|---|---|
| ~/.dotfiles full tree (`assay run .`) | 598/598 | — |
| test-loco-webapp .cursor/nix | 117/117 | — |
| idclear/monorepo .cursor/nix | 138/138 | — |
| solana-yield-optimizer .cursor/nix | 135/136 | 135/136 (identical) |

The single solana failure (`devenv.assay.nix::featureCount`, expects 22
features) reproduces identically on v0.1.0 → pre-existing stale expectation,
NOT an upgrade regression. Left uncommitted per instruction.

## Verification script

`/tmp/hermes-verify-assay-upgrade.sh` (19 checks, all green): static pins,
SRI-vs-artifact byte check, diff-based lock-scope proofs, functional spot-run.
Script bugs found while writing it (lesson: verify the probe before trusting a FAIL):
- grep -c on single-line JSON counts lines not matches → use `grep -o | wc -l`
- asserting SRI presence in wrapper-style templates was wrong; assert `default = null;` there instead

## State at session end

Everything uncommitted across all touched repos (user instruction). dotfiles
tree also carried unrelated pre-existing dirty files (skills/, homarr feature)
— untouched, will ride along with any future commit of the lockfiles.
