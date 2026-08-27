# prek / git-hooks.nix hook schema reference

Distilled from `/nix/store/<hash>-source/modules/hook.nix` (cachix `git-hooks.nix` submodule). Every option here serializes verbatim into the generated `.pre-commit-config.json` via the `raw` attrset at line 259 of `hook.nix`.

## Per-hook options

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `enable` | bool | `false` | include this hook in the generated config |
| `id` | string | (derived) | unique id within the repo |
| `name` | string | (derived from `id`) | human-readable name in prek output |
| `entry` | string or list | (required) | command to invoke (system language invokes directly) |
| `language` | enum | `system` | `system` / `python` / `node` / `rust` / `go` / `coursier` / `pygrep` / `script` / `fail` / `lua` / `docker_image` / `docker` / `gitleaks` |
| `files` | regex | `""` | path regex (re2 syntax) — only run when at least one changed file matches |
| `exclude` | regex | `""` | path regex to exclude (merged from `excludes` list) |
| `types` | list of file types | `[]` | run only on these git file types (`file`, `symlink`, `directory`, …) |
| `types_or` | list of file types | `[]` | OR-group of types |
| `exclude_types` | list of file types | `[]` | exclude these types |
| `pass_filenames` | bool | `true` | append matched file paths to `entry` |
| `fail_fast` | bool | `false` | stop the whole run on this hook's failure |
| `require_serial` | bool | `false` | never run in parallel with other hooks |
| `stages` | list | `default_stages` | which stages fire (e.g. `pre-commit`, `commit-msg`, `pre-push`, `manual`, `post-checkout`, `post-commit`, `post-merge`, `post-rewrite`, `pre-merge-commit`, `pre-rebase`, `prepare-commit-msg`) |
| `verbose` | bool | `false` | **print hook stdout/stderr even on success** |
| `always_run` | bool | `false` | run even when no files match `files`/`types` regex |
| `args` | list of strings | `[]` | additional positional arguments appended to `entry` |
| `before` | list of hook ids | `[]` | ordering constraint — these hooks must run **before** |
| `after` | list of hook ids | `[]` | ordering constraint — these hooks must run **after** |
| `priority` | null or u32 | `null` | execution priority (0 = first); prek only — Python pre-commit ignores this |
| `excludes` | list of regex | `[]` | additional excludes; merged into the single `exclude` regex |

## Top-level options (config-level, set under `git-hooks.*` in devenv)

| Option | Default | Purpose |
|--------|---------|---------|
| `default_stages` | `["pre-commit"]` | stages that apply to a hook with `stages = default_stages` |
| `default_install_hook_types` | `["pre-commit"]` | which stages `prek install` writes hooks for |
| `package` | `pkgs.prek` | the runner binary |
| `tools.<name>` | per-tool defaults | enables `language = "system"` style hook shims |

## How `verbose` flows

```
modules/hook.nix (typed option, mkOption types.bool default false)
  ↓
config.raw = { inherit verbose … }  (line 259)
  ↓
modules/pre-commit.nix runCommand "pre-commit-config.json" (line 67)
  ↓
/nix/store/<hash>-pre-commit-config.json  (do-not-modify marker)
  ↓
.pre-commit-config.yaml  (symlink, regenerated on devenv up)
  ↓
prek reads JSON, honors `"verbose": true`
```

So an edit to `.cursor/nix/features/git-hooks-prek.nix` → `git-hooks.hooks.pre-commit.verbose = true` flows to prek **without any consumer-side glue** as long as the edit sits inside the import chain that devenv evaluates.

## Pitfalls

- The "do-not-modify" marker on the generated JSON is just a comment — prek doesn't enforce it. But editing the JSON in place is lost on the next regen.
- `priority` is prek-only. Python pre-commit ignores it, so setting it on hooks that also run in CI via the Python runner does nothing.
- `default_stages = ["pre-commit", "commit-msg", "pre-push"]` is what `git-hooks-prek.nix` overrides via `git-hooks.default_stages`. Don't confuse that with hook-level `stages` (which is per-hook).
- `language = "system"` invokes `entry` with `$SHELL` resolution — make sure `entry` is on the active shell's PATH. For devenv scripts, devenv puts `pre-commit`/`pre-push`/etc. on the shell PATH at evaluation time. From a non-devenv shell they're not on PATH; that's why submodule pre-push scripts that shell out to `moon run :target` fail outside devenv (see `submodule-sync` pitfalls).