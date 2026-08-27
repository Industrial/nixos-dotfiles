---
id: fleet-rust-tooling
name: fleet-rust-tooling
description: >-
  Decide which dotfiles/NixOS components deserve a Rust rewrite vs staying a
  shell script; conventions for building, packaging (buildRustPackage), wiring
  into features/cli + profiles, and assay/id_effect testing of Rust tools in
  the .dotfiles fleet.
tags: []
related_skills: [nixos-managing, nixos-fleet-management]
---

# Fleet Rust Tooling

Class-level guide for "should this be Rust?" and "how do we ship Rust tools here".

## Script-or-Rust triage

Propose a Rust implementation only when MOST of these hold:

- Long-running process: daemon, HTTP server, timer loop, concurrency fan-out.
- Real parsing: XML/JSON/structured formats or REST clients — regex/sed on
  live config/state files is fragile (real case: arr-wiring seeds *arr
  `config.xml` via grep/sed).
- Retry/backoff, wait-for-ready logic, typed error handling.
- Deserves unit tests via the assay / id_effect workflow (v0.2.1+).

Keep as plain scripts (user directive, 2026-08):

- `bin/` plumbing (`fleet`, `vm/`, `generations/`, `update/`, `ci/` wrappers)
- fish functions/shell wrappers, hyprland/gnome launchers, writeShellApplication glue

Never pitch a "Rust shell" project for what a ≤50-line script already does well.

## Inventory & layout patterns (copy these)

| Tool | Layout | Packaging note |
|------|--------|----------------|
| oomkiller, nix-hash | `rust/tools/<name>` | members of the `rust/workspace.toml` cargo workspace |
| nixos-update-notifier | `rust/tools/nixos-update-notifier` | STANDALONE crate: own Cargo.lock plus an empty `[workspace]` table so buildRustPackage vendors correctly |
| assay, nixq | external repo | consumed as flake `inputs`, packaged upstream |

## Wiring a new tool into the fleet

1. Create `rust/tools/<name>/`; join the workspace (add to `members` in
   `rust/workspace.toml`) OR make it standalone with its own lockfile +
   `[workspace]` header.
2. Feature module `features/cli/<name>/default.nix`: `buildRustPackage`
   (or `callPackage` of a flake input), binary into `environment.systemPackages`.
3. Import from `profiles/base.nix` only if ALL hosts want it; else wire per-host.
4. Colocated `<stem>.assay.nix` suite; gate = `devenv shell -- assay run .`.
5. User-level systemd units (timers/notifications hitting the session D-Bus)
   live in the feature module — see `features/cli/nixos-update-notifier/default.nix`
   for the Nice/IOSchedulingClass pattern for heavy periodic jobs.

## Pitfalls

- New crate not added to `rust/workspace.toml` members → cargo resolver errors.
- Standalone crate without the empty `[workspace]` table → attaches to a
  parent workspace and breaks buildRustPackage hashing.
- `pkgs.writers.writePython3` enforces pycodestyle at BUILD time — nontrivial
  embedded logic is safer as Rust (see nixos-managing pitfalls).
- Releases follow devops/release-engineering; assay/id_effect v0.2.1 landed
  2026-08 — bump consumers in the same change.

## Candidate backlog (fleet audit 2026-08)

Ranked Rust-replacement candidates with file paths and rationale:
see `references/replacement-candidates.md`.

1. arr-wiring reconciler (replace sed-on-XML + writePython3)
2. Alert bridge (Alertmanager webhook receiver + active port probes → textfile collector)
3. vulnix replacement (OSV-backed closure scanner)
4. rustic, if/when backup coverage gets added (none exists today)
