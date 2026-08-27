# Assay (Industrial/assay) release-state snapshot — 2026-08-23

Repo: `/data/Code/rust/assay` → git@github.com:Industrial/assay.git

## v0.2.0 — SHIPPED (2026-08-23)

All channels live; nothing outstanding from the audit below.

- **GitHub:** release `v0.2.0` (tag on `1321f46`), 3 platform tarballs
  (x86_64-linux-gnu, aarch64-darwin, x86_64-darwin) via release.yml;
  ci + release workflows green.
- **crates.io:** all 5 workspace crates published at 0.2.0 in dep order
  nixstore→nixq→nixdrv→nixfetch→nix-assay. End-to-end proof: clean-dir
  `cargo install nix-assay --locked` replaced v0.1.0 with v0.2.0 and the
  registry-installed binary ran the smoke suite 12/12.
- **Git:** main == origin/main at `d02232a`; tag pushed; tree clean.

Release commits (chronological):
c0111df feat(nix): add common assert.nix helper library ·
40e9ab5 test(ci): run dogfood suite alongside smoke ·
8ab552e chore(release): bump workspace to 0.2.0 ·
ddbad4d fix(nix): relocate assert.nix to nix/ and repair assertListOfType ·
1321f46 fix(ci): tolerate missing criterion output until benches exist ·
d02232a docs(maestro): record v0.2.0 release plan spec.

## Pipeline facts

- Tag-triggered release workflow: `.github/workflows/release.yml`
  (`on: push: tags: v*`) → 3-platform tarballs via softprops/action-gh-release@v2,
  `generate_release_notes: true`. Proven twice (v0.1.0, v0.2.0); no CHANGELOG.md
  needed or wanted (user decision).
- CI workflow (`ci.yml`): check/test + smoke AND dogfood suites + benchmark job
  (no-op-safe via `if-no-files-found: ignore` — no `[[bench]]` targets yet).
- Local gates via moon targets: check, lint, test, audit, bench, docs,
  assay (smoke+dogfood). prek hooks: moon pre-commit/pre-push, commitizen msg.
- Versioning now single-sourced: `[workspace.package] version = "0.2.0"` +
  `version.workspace = true` in all 5 members; inter-crate reqs `0.2.0`;
  flake.nix string still manual (line ~29).

## Bugs fixed during release (both were pre-existing landmines)

1. `assertListOfType` in assert.nix used pseudo-Nix (`list.map`, `x.isString`)
   — never worked anywhere. Repaired with `builtins.map` + `builtins.isString`.
2. The dogfood suite imports `../../assert.nix` FROM `nix/assay/tests/`, which
   resolves to `nix/assert.nix` — not repo root. Root copy was the orphaned
   good version; relocated to `nix/`. Lesson: resolve import paths from the
   importer's directory before declaring a file stray (now in SKILL.md).

## Historical audit snapshot (pre-release, kept for pattern reference)

- Unpushed had been: edb5cef (bench CI job + eval.rs/simple_eval.rs), 4f9df02
  (roadmap plan). Remote main was ccf69c1.
- Blocker found: tracked `nix/assay/tests/dogfood.assay.nix` imported untracked
  assert.nix → fresh clones failed dogfood; CI didn't notice (smoke only then).
- Name collision note: plain `assay` on crates.io is an unrelated 2022
  proc-macro crate (v0.1.1) — workspace publishes as `nix-assay`.

Plan spec: `.maestro/specs/assay-v0.2.0-release.md` (t1–t7, all completed).
