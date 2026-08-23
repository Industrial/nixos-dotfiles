# Assay (Industrial/assay) release-state snapshot — 2026-08-23

Repo: `/data/Code/rust/assay` → git@github.com:Industrial/assay.git

## Pipeline facts

- Tag-triggered release workflow: `.github/workflows/release.yml` (`on: push: tags: v*`).
  Builds 3-platform tarballs (x86_64-unknown-linux-gnu, aarch64-apple-darwin,
  x86_64-apple-darwin), uploads via softprops/action-gh-release@v2 with
  `generate_release_notes: true`. Proven by v0.1.0 release (2026-08-09, assets
  published by github-actions[bot]).
- CI workflow: `ci.yml` runs cargo check/test + smoke suite; benchmark job added in
  edb5cef. Does NOT run the dogfood suite.
- Local gates via moon targets: check, lint (fmt+clippy -D warnings), test (nextest),
  audit, bench, docs, assay (smoke+dogfood). prek hooks: moon pre-commit/pre-push,
  commitizen commit-msg (`cz check`).
- Version surfaces at audit time: 5 crate manifests all literal `0.1.0`
  (crates/assay = pkg name `nix-assay`, plus nixdrv, nixfetch, nixq, nixstore),
  inter-crate dep reqs `0.1.0`, flake.nix line ~29 version string, Cargo.lock.
  Root Cargo.toml already has `[workspace.package]` scaffolding for inheritance
  but members don't use it yet.

## Audit findings (2026-08-23)

- Unpushed: 2 commits — edb5cef (bench CI job + eval.rs/simple_eval.rs work),
  4f9df02 (history/2026-08-19-21-34-03-PLAN.md roadmap). Remote main at ccf69c1.
- Uncommitted: root `assert.nix` (functional) untracked; stray stub copy
  `nix/assert.nix` (pass-through `typ: list: list`) divergent from it.
- Blocker: tracked `nix/assay/tests/dogfood.assay.nix` imports root `assert.nix`
  → fresh clones fail dogfood; CI doesn't notice (smoke only).
- Unreleased: ccf69c1, 4f9df02, edb5cef since tag v0.1.0 (= f871b35).
- Unpublished: `nix-assay` absent from crates.io; docs/install.md and README
  already promise `cargo install nix-assay --locked`. Name collision note: plain
  `assay` on crates.io is an unrelated 2022 proc-macro crate (v0.1.1).

## v0.2.0 plan

Full task breakdown written to `.maestro/specs/assay-v0.2.0-release.md`:
t1 consolidate assert.nix → t2 gate dogfood in CI → t3 bump to 0.2.0 (workspace
inheritance across 5 crates + inter-crate reqs + flake string + lockfile) →
t4 docs truth-check → t5 full gate sweep → t6 push+tag v0.2.0 (release wf builds
assets) → t7 crates.io publish dry-run then real, dep order
nixstore→nixq→nixdrv→nixfetch→nix-assay (needs user's registry token; deferrable).

Open decisions left with user: drop stray `nix/assert.nix` stub (yes assumed);
CHANGELOG.md vs GH generated notes (GH notes assumed sufficient).
