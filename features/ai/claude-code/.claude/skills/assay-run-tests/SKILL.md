---
name: assay-run-tests
description: Run Assay (Nix unit testing) suites. `assay` is on $PATH via devenv.nix (`cursor.features.program-assay.enable = true`). Use `assay run <path>` to execute, `assay discover <path>` to list claims, `assay laws` for property laws.
---

# Run Assay unit tests

Assay is the monorepo's Nix-based unit-testing tool. The `assay` binary is exposed via `devenv.nix` (`cursor.features.program-assay.enable = true`) and lives on `$PATH` once a devenv shell is active. No install step needed inside a shell.

## Commands

- `assay run <path>` — execute the suite at `<path>` (file or directory). Supports `--json`, `--format <fmt>`, `--update-snapshots`, `--case-timeout-ms <ms>`, `--retry-flaky-eval`, `--no-batch`.
- `assay discover <path>` — list claims without running them. Useful to scope work before a run.
- `assay laws [--seed N] [--json]` — run the property-based "laws" suites (random seed; default 0).

## Workflow

1. Confirm `which assay` resolves. If not, enter the devenv shell first (`devenv shell` or run via `devenv shell -- assay run …`).
2. `assay discover <path>` to see claim count and names.
3. `assay run <path>` to execute. Use `--json` when piping into other tooling or when you want a structured summary.
4. For flaky failures, retry with `--retry-flaky-eval` before investigating.
5. For snapshot drift, re-run with `--update-snapshots` only after manually inspecting the diff.

## Pitfalls

- `assay run` without a devenv shell fails with "command not found" — the binary only resolves inside a devenv nix shell.
- `--no-batch` disables the tryEval mega-batch (one nix process per claim). Slower but isolates which claim crashed; use it when a batch run aborts mid-way and you need to bisect.
- `--update-snapshots` writes changes silently — review the diff in version control before committing.
- `assay laws` uses a fixed seed by default (0). Pass `--seed N` to reproduce a specific property-test failure.
- **treefmt's nix formatter rewrites `...}:` to `... }\n}: let` on the closing brace of an attribute set that introduces a `let` binding.** If you author `nix/features/program-<name>.nix` without going through the local `nix fmt` step, the first `git commit` will fail in the `monorepo:format` prek hook, the formatter will rewrite the file, and prek will auto-restore the working tree from its patch stash. Re-`git add` the rewritten file and retry the commit. To avoid the round-trip, write the wrapper in the formatter's preferred style up front (space before `}` and `let` on the same line as the closing brace).

## When adding a new program feature to nix/features/

Adding a feature (e.g. provisioning a new CLI/MCP server via devenv) is a 5-step operation that must update **three** files in addition to the feature itself, or the barrel-level `devenv.assay.nix` and `default.assay.nix` will fail.

1. `nix/features/<name>/package.nix` — the actual `stdenv.mkDerivation` / `buildPythonPackage` etc. Make sure `pname` matches the binary name the test will look for.
2. `nix/features/program-<name>.nix` — devenv wrapper. Mirror `program-serena.nix` / `program-omniroute.nix` (enable option under `cursor.features.program-<name>`, register `[pkgs.callPackage ./<name>/package.nix {}]` under `packages` when enabled).
3. `nix/features/program-<name>.assay.nix` — co-located. Two claims are the minimum: disabled state is empty, enabled state has the `pname` in `packages` (use `has`/`builtins.elem` on `packageNames`).
4. `nix/devenv.nix` — add `./features/program-<name>.nix` to the `imports` list.
5. `nix/devenv.assay.nix` AND `nix/default.assay.nix` — both list feature names explicitly and assert the count. Add `<name>` to the `expected`/`hermesFeatures` list and bump the `featureCount`/`hermesFeatureCount` literal. **Both files must change in the same patch**; updating only one leaves a count mismatch that the other test catches.

Additionally, the root `devenv.nix` must set `cursor.features.program-<name>.enable = true;` next to the other `program-*` enables, otherwise the feature is wired but never provisioned. This step has no assay coverage — verify by reading the diff or by confirming the binary is on `$PATH` inside `devenv shell`.

After all five edits, `assay run nix/` should pass with exactly +2 new claims (the new `disabled` + `package` assertions). If the count of new claims is wrong, you skipped a barrel file.

For a worked example (porting `maestro` from `~/.dotfiles/features/ai/maestro/` into the devenv feature layout) and a copy-paste-ready checklist, see `references/adding-a-program-feature.md`.

## Common assay failure modes in nix/

- **"expected: [...6 names...] got: [...5 names...]"** in `devenv.assay.nix::exposesHermesFeatures` — you added a feature file but forgot to import it in `nix/devenv.nix`, or forgot to add it to the `expected` list.
- **`featureCount` says N but got M** — barrel count drift. Re-check both `devenv.assay.nix` and `default.assay.nix`.
- **New feature's `package` claim fails with `false`/`true` mismatch** — the feature wrapper's `packages` list contains the derivation, but `packageNames` is matching on `pname`/`name`. Confirm `pname` in `package.nix` matches the string in the test's `has` call.
- **`disabled` claim returns non-empty** — your `lib.mkIf cfg.enable { ... }` is registering things at the top level instead of inside the `mkIf` block. Compare against `program-serena.nix` for the minimal pattern.
