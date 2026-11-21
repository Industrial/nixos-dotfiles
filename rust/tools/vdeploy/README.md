# vdeploy

The fleet's pull-based deploy agent, in **observe mode** (GH-159). It runs next to comin.
It works out the switch comin would make, logs it, and never makes it. The take-over
(switch, health check through vhealth, rollback) is #160. vdeploy is written in Voltaic
0.2.1 (`src/*.vlt`, compiled by `build.rs`) with id_effect 0.13.0.

```
vdeploy --host NAME [--once] [--url URL] [--branch NAME] [--repo DIR]
        [--interval DURATION] [--debounce DURATION] [--tick DURATION]
        [--state-dir DIR] [--textfile-dir DIR] [--db FILE] [--git PROG] [--nix PROG]
        [--dotfiles PATH [--dotfiles-user USER] [--dotfiles-group GROUP] [--dotfiles-home DIR]]
```

No flag switches anything. The code has no switch capability.

## One plan

1. **Poll**: `git fetch` of `main` from `--url` into vdeploy's own clone (`--repo`, default
   `/var/lib/vdeploy/repo`; never the user's checkout). The fetch is retried on a bounded
   exponential Schedule (10 s, then 20 s).
2. **Verify**: the commit must be on `refs/remotes/origin/main`, as last fetched over TLS
   from the pinned URL (`git merge-base --is-ancestor`). A commit that is not there is
   refused (`Unverified`). See "Signatures" below.
3. **Evaluate**: `nix eval --raw git+file://<repo>?rev=<sha>#nixosConfigurations."<host>".config.system.build.toplevel.drvPath`.
   The flake is the commit, never a work tree.
4. **Realise**: first through the `Fetcher`, which only substitutes, then through the `Builder`
   for whatever is left (`nix build <drv>^out`). The live Fetcher is a temporary one,
   `nix build --max-jobs 0`, with C++ Nix doing the substitution. It is swapped for vfetch
   (#155) when that lands. Only the capability's implementation changes.
5. **Diff**: vdiff's code, linked as a library, produces the schema-1 report of
   `/run/current-system` against the new toplevel.
6. **Log**: one journal line saying what it would do (`would switch drakkar from <rev> to
   <sha>: …; Observe mode: not switching.`, or `already runs …: nothing to switch.`), one
   JSON line on stdout, `<state-dir>/plan.json` (the latest plan with the whole vdiff
   report), and one line appended to `<state-dir>/plans.jsonl` (the history, counts only).

## No starvation

comin cancels a host's build whenever main moves, so a slow host never finished a
generation. vdeploy is built differently:

- Two fibers share one `Ref<Status>`. The **poller** (a spaced Schedule, `--interval`) only
  records the newest head. The **worker** (a spaced Schedule, `--tick`) runs a whole plan
  inside one step of its repeat. Nothing can preempt a plan, so a build in flight is
  **never cancelled** because main moved.
- **Latest-wins**: when a plan finishes, the next one is for the newest head. The commits in
  between are skipped and counted (`vdeploy_commits_skipped_total`).
- **Debounce** (`--debounce`, default 0): main must stay on one commit for that long before
  a plan starts. The window is counted in whole polls, so it is deterministic under the test
  clock. Slow hosts can be given a longer window.
- A commit whose plan fails is not retried until main moves again.

The decision rules are pure (`src/watch.vlt`). `src/agent.vlt` tests them end to end on the
id_effect test clock: commits land every second, a build takes five, and the agent still
plans the newest commit. Every build it starts finishes, and the commits in between are
skipped.

## The user's dotfiles checkout

Each host's nushell config symlinks into `~/.dotfiles`, and comin never updates that
checkout. A stale one breaks the nu login shell and GDM. With `--dotfiles`, every poll does
this, as `--dotfiles-user` (through `setpriv`, with no PAM and no shell):

```
git fetch --no-recurse-submodules <url> main
git merge --ff-only FETCH_HEAD
```

It **refuses**, and reports the reason in the journal (once per change) and in
`vdeploy_dotfiles_state{state=…}`, when the checkout:

- is not on `main` (`wrong-branch`);
- has changes to tracked files (`dirty`). Untracked files and submodule state do not count,
  because a fast-forward touches neither;
- is ahead of main (`ahead`);
- has diverged from main (`diverged`).

A checkout that is already at the head vdeploy fetched is `up-to-date`, and no network call
is made.

## Signatures

The repository does not sign its commits. Of the last 300 first-parent commits on main on
2026-11-21, 257 are unsigned direct commits. The other 43 are PR squash merges, which GitHub
signs with its own web-flow key. A signature check would refuse most of the history, and
checking GitHub's key needs gpg and a pinned key. So verification is ancestry on
`origin/main`, fetched over TLS from the pinned URL. Main only takes PR merges. Whether
GitHub signed a commit is recorded in each plan (`signedByGithub`) but not enforced. #160
can turn that into a requirement once every commit on main is a signed merge.

## Metrics

The metrics go in `<textfile-dir>/vdeploy.prom` for node_exporter's textfile collector,
rewritten on every poll:

| metric | meaning |
|---|---|
| `vdeploy_generation_age_seconds` | now minus the commit time of the commit the running system was built from (`system.configurationRevision`); how far a starved host lags |
| `vdeploy_switch_pending` | 1 when the last plan would switch |
| `vdeploy_plans_started_total`, `…_finished_total`, `…_failed_total` | finished equals started, or is one behind while a plan runs (never cancelled) |
| `vdeploy_commits_skipped_total` | commits never planned because a newer one landed (latest-wins) |
| `vdeploy_last_poll_timestamp_seconds`, `vdeploy_poll_failures_total`, `vdeploy_polls_total`, `vdeploy_head_changes_total` | the poller |
| `vdeploy_last_plan_timestamp_seconds`, `vdeploy_last_plan_duration_seconds` | the worker |
| `vdeploy_dotfiles_state{state=…}` | 1 for the checkout's current state |
| `vdeploy_observe_mode` | always 1 in this version |

## Capabilities

| capability | live | tests |
|---|---|---|
| `Source` (head, verify, commit_time) | `git` on vdeploy's clone | `Scripted` |
| `Nix` (drv) | `nix eval` | `Scripted` |
| `Fetcher` (fetch) | `nix build --max-jobs 0` (temporary, until vfetch) | `Scripted` |
| `Builder` (build) | `nix build` | `Scripted` (a build takes N s on the test clock) |
| `Differ` (json) | vdiff on the store database | `Scripted` |
| `Host` (running, dotfiles) | `/run/current-system`, its `nixos-version`, git via `setpriv` | `Scripted` |

## Tests

Run `cargo test`. `default.nix` runs the tests as part of the package build, with git in the
sandbox. The NixOS VM test is `features/nix/vdeploy/test.nix`
(`checks.x86_64-linux.vdeploy-vm`).
