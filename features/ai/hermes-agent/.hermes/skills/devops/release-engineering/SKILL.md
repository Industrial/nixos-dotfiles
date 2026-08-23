---
name: release-engineering
description: >
  Audit and execute software releases: enumerate unpushed/uncommitted/unreleased/
  unpublished work, pick version bumps, run quality gates, tag-triggered CI
  releases, and registry publishing (crates.io et al). Use when asked "what's
  unreleased/unpushed/unpublished?", "cut a release", "bump versions", or before
  publishing packages.
tags: [release, versioning, ci, publishing, git]
---

# Release Engineering

Class-level skill for release-state audits and release execution in any repo.

## Part 1 — Release-state audit ("what's unreleased / unpushed / unpublished?")

Batch the read-only probes together (they are independent):

1. Local git state:
   - `git status` + `git branch -vv` → uncommitted/untracked files, ahead/behind counts
   - `git log --oneline @{u}..HEAD` → unpushed commits
   - `git stash list`
2. Release boundary:
   - `git tag --sort=-creatordate | head`, then `git log --oneline <latest-tag>..HEAD` → unreleased commits
   - Confirm the tag exists on the remote: `git ls-remote --tags origin` (a local tag can lie about "released")
3. Published artifacts:
   - GitHub releases: `curl -s https://api.github.com/repos/<org>/<repo>/releases` (public repos need no auth; check `draft`/`prerelease` flags and asset list)
   - crates.io: `curl -s -A '<contact-user-agent>' https://crates.io/api/v1/crates/<name>` — **User-Agent header is mandatory**; bare curl is rejected with a data-access-policy error that reads like a ban but is not one
4. Untracked-but-referenced files: grep tracked files for imports/paths pointing at untracked files → fresh-clone breakage CI may not catch (see Pitfalls)
5. Divergent copies: when two similarly-named files exist, `diff` them AND trace who imports which — resolve every import path *from the importer's directory*, not the repo root. A suite at `nix/assay/tests/x.nix` importing `../../assert.nix` loads `nix/assert.nix`, NOT root `assert.nix`; reasoning from the repo root inverts which copy is live. Confirm with an actual runner/suite execution before declaring any copy stray.

Report results in four buckets: **unpushed / uncommitted / unreleased (since last tag) / unpublished (registry)**.

## Part 2 — Release execution checklist

1. Fix release blockers FIRST: files that builds/tests import but are untracked; CI coverage gaps that let them slip.
2. Pick SemVer deliberately: 0.x minor = compatible additions (new modules/surface); patch = fixes only.
3. Enumerate ALL version surfaces before bumping:
   - workspace manifest + every member manifest, AND inter-crate dependency version reqs
   - lockfile (regenerate after bump)
   - non-cargo surfaces: flake.nix version strings, package.json, embedded `env!("VERSION")`-style constants
4. Truth-check docs: every install command and expected-output claim in README/docs gets verified locally or removed.
5. Run the project's full local gate sweep (moon targets, make targets, or CI-equivalent) on the final tree.
6. Push, then tag: check `.github/workflows/release.yml` for `on: push: tags` — tag-triggered workflows build artifacts and open the GH release automatically. Verify the Actions run succeeded and assets appeared; don't assume.
7. Registry publish LAST: `cargo publish --dry-run` per crate in dependency order (leaf crates first), then real publish (needs `cargo login` token). Defer cleanly if credentials are unavailable. Cargo auto-polls after upload ("waiting for <crate> to be available at registry") until the dep indexes — no manual sleeps needed between leaves. Post-publish proof: `cargo install <crate> --locked` from a clean temp dir, then RUN something with the installed binary (e.g. its test suite) — API `max_version` alone doesn't prove the artifact resolves/builds. A transient `Failed to connect to index.crates.io` right after publishing is a blip; retry before investigating.
8. Ad-hoc verification scripts (when a harness demands fresh evidence or canonical commands aren't detected): write to `/tmp/hermes-verify-*.sh`, keep checks greppable, and quote carefully — `grep -c` counts LINES, so on single-line JSON output (`cargo metadata --format-version 1`) it returns 1 no matter how many matches; use `grep -o | wc -l`. Report the result as ad-hoc verification, not suite green.

## Pitfalls

- **crates.io dry-run failures for downstream crates are EXPECTED pre-publish**: "failed to select a version for the requirement `dep = ^X.Y` / candidate versions found which didn't match" just means the leaf dep isn't on the index yet — sequencing, not a packaging bug. Only the leaf crate's dry-run can be fully clean. Real publishes must go leaves-first with retries between (`for c in ...; do cargo publish -p $c || break; done`).
- **Verify registry credentials BEFORE tagging.** A stale token surfaces only at real-publish time as `status 403 Forbidden: authentication failed`; by then the tag has already fired the GH release and install docs point at a crate that doesn't exist. Probe early: `~/.cargo/credentials.toml` existing ≠ valid.
- **No `[[bench]]` targets → `cargo bench` is a silent no-op** (exit 0, nothing measured, no `target/criterion`). A CI bench job added around it will fail at artifact upload — fix with `if-no-files-found: ignore` until real benches land (see `rust/rust-benchmark-ci`).
- devenv-wrapped gates emit ~30 lines of shell-sync noise before real output; pipe through `tail -N` / `grep -E 'passed|Fail'` so results stay readable in logs.
- crates.io API rejects User-Agent-less requests — set one; the error text suggests abuse but it's just policy enforcement.
- Registry name squatting: the desired name may be an unrelated crate (e.g. `assay` on crates.io is a 2022 proc-macro). Check availability BEFORE docs promise `cargo install <name>`; publish under a prefixed name instead.
- CI that exercises only part of the shipped test surface (e.g. smoke but not dogfood suites) hides fresh-clone breakage — gate every suite the repo ships.
- Literal versions duplicated across manifests drift from each other; prefer workspace inheritance (`version.workspace = true`) so one bump moves everything.
- Local tag ≠ remote tag: verify with `ls-remote` before claiming something is released.
- GH release "published by github-actions[bot]" with generated notes means no CHANGELOG is needed — but confirm the repo actually has a tag-triggered workflow before relying on it.

## References

- `references/assay-v0.2.0-release-state.md` — Assay repo (Industrial/assay) pipeline facts, 2026-08-23 audit snapshot, v0.2.0 plan pointer
