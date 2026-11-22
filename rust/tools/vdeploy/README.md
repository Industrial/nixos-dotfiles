# vdeploy

The fleet's pull-based deploy agent. In **observe mode** (GH-159, the default) it runs next
to comin, works out the switch comin would make, logs it, and never makes it. In **deploy
mode** (GH-160, the take-over) it switches the host itself: every switch is health-checked
with vhealth and rolled back when unhealthy, and comin is retired. vdeploy is written in
Voltaic 0.2.1 (`src/*.vlt`, compiled by `build.rs`) with id_effect 0.13.0.

```
vdeploy --host NAME [--once] [--url URL] [--branch NAME] [--repo DIR]
        [--interval DURATION] [--debounce DURATION] [--tick DURATION]
        [--state-dir DIR] [--textfile-dir DIR] [--db FILE] [--git PROG] [--nix PROG]
        [--dotfiles PATH [--dotfiles-user USER] [--dotfiles-group GROUP] [--dotfiles-home DIR]]
```

```
vdeploy --host NAME --mode deploy [--health-window DURATION] [--systemd-run PROG] [APPLY OPTIONS] …
vdeploy apply [--toplevel PATH] [--state-dir DIR] [--textfile-dir DIR] [APPLY OPTIONS]

APPLY OPTIONS: [--health-window DURATION] [--health-every DURATION] [--vhealth PROG]
               [--profile PATH] [--gcroot PATH] [--nix-env PROG] [--nix-store PROG]
               [--systemctl PROG] [--comin-unit UNIT] [--health-as USER [--setpriv PROG]]
```

In observe mode nothing switches. In deploy mode the switch is made only by `vdeploy apply`
(below), in its own transient unit.

## Deploy mode: the apply transaction (GH-160)

For each plan that would switch, the daemon runs

```
systemd-run --unit=vdeploy-apply --service-type=exec --collect --wait \
  vdeploy apply --toplevel X <apply options>
```

and reads the outcome back from the ledger. `vdeploy apply` (`src/apply.vlt`):

1. `prev` = `/run/current-system`. It refuses when X was rolled back before (marked bad:
   `<state-dir>/bad/<store name>`) or when comin is active (one deployer at a time). It
   writes `inflight.json` (X, prev) and GC-roots X.
2. `X/bin/switch-to-configuration test`: X runs; the boot entries are not touched.
3. Health: `X/sw/bin/vhealth check --config X/etc/vhealth/probes.json --json --wait W` (X's
   own vhealth and probes), as `--health-as` (nobody, through setpriv) like vhealth's own
   daemon. Exit 0 is healthy; 1 means a critical probe is down (`failing`).
4. Healthy: `nix-env -p /nix/var/nix/profiles/system --set X`, then
   `X/bin/switch-to-configuration boot`. Only now is X the boot default.
5. Otherwise, or when 2 failed: `prev/bin/switch-to-configuration test`, and X is marked bad.
   The boot entries were never written, so a crash anywhere before step 4 reboots into
   prev.

An apply killed between 2 and 4 leaves `inflight.json`. The next apply, or the daemon at
start, finishes the decision for it first: health check, then keep or roll back.

The outcome goes to `<state-dir>/last.json`, `<state-dir>/deploys.jsonl` and
`<textfile-dir>/vdeploy-apply.prom` (`vdeploy_applies_total{result}`,
`vdeploy_rollbacks_total`, `vdeploy_last_result{result}`,
`vdeploy_last_apply_timestamp_seconds`). `vdeploy apply` exits 0 when the host ends on X,
and 1 when it was rolled back or refused.

Why a transient unit: a switch can restart or remove `vdeploy.service`, and that must not
kill the switch. comin shows what goes wrong otherwise: it runs switch-to-configuration as
its own child, with the output piped into itself. The fixed unit name is also the lock.
The daemon waits on a Schedule until no `vdeploy-apply` runs before it starts one.

Retiring comin: in deploy mode, `features/nix/vdeploy` keeps `comin.service` as a
tombstone (`X-RestartIfChanged=false`, `Restart=no`, no `WantedBy`). So the comin that
applies the take-over generation finishes that switch, then exits as it does whenever its
unit file changes, and stays down. At start, the daemon waits on a Schedule until no
`switch-to-configuration` is left in comin's cgroup, then stops the unit.

## The wake (GH-246)

```
vdeploy wake [--wait] [--timeout DURATION] [--fifo PATH] [--state-dir DIR]
```

A wake makes the poller poll main **now** instead of at the end of `--interval`. It
carries nothing: no commit, no toplevel, no flag. Everything after it is the ordinary
path (fetch from the pinned URL, verify, debounce, bad marks, the health gate, rollback),
so the worst a wake can do is make a host poll sooner. The poll on `--interval` stays the
default and the fallback. `fleet deploy` is `ssh <host> vdeploy wake --wait`.

- **The FIFO** `/run/vdeploy/wake` is created by systemd-tmpfiles as `root:vdeploy-wake
  0620`, in deploy mode only. The group holds the fleet's operator alone
  (`features.nix.vdeploy.wake.operators`, normal users only, asserted).
- **The daemon** (`--wake-fifo`) reads it in cycles: open it read-write (so there is never
  an end of file), wait up to 60 s for a write on the runtime's reactor, drain whatever is
  there, close. Each cycle that read something is one offer to a sliding queue of one, so a
  burst of writes is one poll. A missing, replaced or unreadable FIFO is logged once and
  retried every cycle. Nothing on the FIFO can end the daemon, and no signal is involved.
- **The poller** waits `sleep(interval).race_first(wakes.take())`. A wake during a plan is
  held, never cancelling the plan (the worker is unchanged).
- **`vdeploy wake`** opens the FIFO write-only and non-blocking and writes one byte,
  retrying for up to 2 s, because the reader reopens between cycles. Exit codes:
  - 0: woken;
  - 69: no FIFO here (observe mode, or no wake support);
  - 75: vdeploy is not reading it (starting or restarting), so it polls on its interval;
  - 77: not in vdeploy-wake.
- **`--wait`** follows the outcome as the operator, from files any user may read:
  `status.json` (written after every poll: `head`, `done`, `polledAt`, `planning`,
  `debounceLeft`), `plan.json` and `last.json`. It prints one line and exits 0 when the
  host is on main (switched, already, or observe mode's "would switch") and 1 otherwise
  (rolled back, refused, the plan failed, not settled in `--timeout`). A debounced main is
  reported and left to the interval.

Rollback: `features.nix.vdeploy.wake.enable = false;` (no flag, no FIFO, no group).

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
| `vdeploy_observe_mode`, `vdeploy_deploy_mode` | 1 for the mode the daemon runs in |

## Capabilities

| capability | live | tests |
|---|---|---|
| `Source` (head, verify, commit_time) | `git` on vdeploy's clone | `Scripted` |
| `Nix` (drv) | `nix eval` | `Scripted` |
| `Fetcher` (fetch) | `nix build --max-jobs 0` (temporary, until vfetch) | `Scripted` |
| `Builder` (build) | `nix build` | `Scripted` (a build takes N s on the test clock) |
| `Differ` (json) | vdiff on the store database | `Scripted` |
| `Host` (running, dotfiles) | `/run/current-system`, its `nixos-version`, git via `setpriv` | `Scripted` |
| `Deployer` (retire, apply) | `systemctl`, `systemd-run vdeploy apply` (deploy mode) | `takeover::Scripted` |
| `System` (`vdeploy apply`) | switch-to-configuration, nix-env, nix-store, vhealth | `apply::Scripted` |

## Tests

Run `cargo test`. `default.nix` runs the tests as part of the package build, with git in the
sandbox. The NixOS VM test is `features/nix/vdeploy/test.nix`
(`checks.x86_64-linux.vdeploy-vm`).
