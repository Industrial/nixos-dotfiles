# vbump

vbump does per-input flake.lock updates and opens one pull request per input (GH-189).
It replaced the single all-inputs bump of the old `.github/workflows/update-flake-lock.yml`,
and since GH-247 it is the only lock updater (`.github/workflows/vbump.yml`).
It is written in Voltaic 0.2.1 (`src/*.vlt`, compiled by `build.rs`) with
id_effect 0.13.0. The name is `vbump`, not `vlock`, because nixpkgs already ships
`vlock` (the console locker).

```
vbump run [--input NAME]... [--dry-run] [--jobs N] [--repo DIR] [--rev REV]
          [--remote NAME] [--base-branch NAME] [--label NAME] [--gh-repo OWNER/NAME]
          [--run-url URL] [--summary FILE] [--out DIR] [--db FILE]
          [--committer 'NAME <EMAIL>'] [--auto-merge]
```

vbump runs these steps for each root input of the flake, one input at a time
(`--input` limits which inputs; without it, every input runs):

1. **relock**: `nix flake update <input>`, in a scratch directory that holds the base
   revision's `flake.nix` and `flake.lock`. C++ Nix stays the lock resolver. This step
   is retried on a bounded exponential id_effect Schedule, because it is the step that
   fetches.
2. **unchanged**: if no lock node moved, the input is up to date and gets no PR.
3. **hosts**: every `nixosConfigurations` host is evaluated against the new lock with
   `nix eval --reference-lock-file <lock> git+file://<repo>?rev=<base>#…drvPath`. The
   base is a commit, never the work tree. Each host is then dry-built with
   `nix build --dry-run <drv>^*`. If a host does not evaluate or does not dry-build,
   the input fails.
4. **diff**: each host's toplevel derivation closure is diffed against the base's with
   vdiff's own code, used as a library. The result is the schema-1 `vdiff --json`
   report (see `../vdiff/README.md`). If a host's derivation did not move, it is
   marked unchanged. If the base has no derivation for a host, or the diff fails,
   that host gets a note instead of a diff.
5. **publish**: the new lock goes to `update/flake-lock-<input>` as one commit on the
   base, and that branch's PR is opened or refreshed. The commit is built with git
   plumbing and dated by the base, so the same base and lock always give the same
   commit. That makes a retried or repeated publish a no-op. `--dry-run` publishes
   nothing. With `--auto-merge` (GH-247), vbump then arms GitHub's auto-merge
   (squash, through GraphQL `enablePullRequestAutoMerge`, GH-314) on the PR unless it
   is armed already, so the PR merges itself once `main`'s required `ci / all-green`
   passes. Failing to arm it fails the input. A PR GitHub calls clean (green and
   mergeable already) is refused by the mutation and left open with a warning: vbump
   never runs `gh pr merge`, whose `--auto` merges a clean PR on the spot (#308).

Concurrency: inputs run `--jobs` at a time (`for_each_par`, `Bounded`). The hosts of
one input run sequentially, because one evaluation takes about 3 GB. Each input's
outcome is a value, so one input that fails stops nothing else. The run exits 1 when
any input failed.

The summary table (one row per input) is printed on stdout and written to
`--summary`. `--out DIR` gets every proposal's PR body (`<input>.md`) and each host's
report (`<input>.<host>.json`).

## Capabilities

| capability | live | tests |
|---|---|---|
| `Nix` (hosts, relock, drv, dry_build) | `nix` commands | `Scripted` |
| `Differ` (json) | vdiff on the store database | `Canned` |
| `Github` (publish) | `git` plumbing + `gh` | `Recording`; `DryRun` for `--dry-run` |

## Where it runs

- **Scheduled**: `.github/workflows/vbump.yml`, weekly, with `--auto-merge`. It is the
  only lock updater; the rollback is restoring the old workflow from git history
  (`docs/runbooks/updates.md` §1).
- **By hand**: `bin/update/flake`, on hosts with `features.cli.vbump`.

## Tests

Run `cargo test`. `default.nix` packages the crate as its own test run, with git in
the sandbox for the forge test.
