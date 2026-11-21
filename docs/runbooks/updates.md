# Updates runbook

How the fleet takes upstream updates, and how to back one out. Policy and rationale:
[ADR-0006](../adr/0006-update-policy.md). Activation mechanics: [fleet-deploy](./fleet-deploy.md).

```
weekly cron ──► update-flake-lock.yml ──► vbump: per input, PR "chore(flake): bump <input>"
                                          ├─ PR workflow → ci.yml → ci / all-green  (required)
                                          └─ PR body: the input's lock move + per-host
                                             dry build and closure diff (vdiff --json)
operator reviews ──► merge to main ──► comin on every host: switch (≤ 300s)
                                   └─► nixos-update-notifier: "reboot pending" if kernel moved
```

Nothing in this chain merges, reboots or switches to an unmerged tree on its own.

## 1. Get lock-bump PRs

- **Scheduled:** Mondays 03:23 UTC. `vbump` (rust/tools/vbump, GH-189) takes each root
  input on its own: `nix flake update <input>`, evaluate and dry-build every
  `nixosConfigurations` host against that lock, diff each host's derivation closure against
  `main`, and open or refresh one PR per input on `update/flake-lock-<input>`. An input
  that did not move gets no PR. An input that does not evaluate or dry-build on some host
  gets no PR and turns the run red; the other inputs still get theirs. The run's summary
  table is on the workflow run page, and every PR body and `vdiff --json` report is in its
  `vbump-proposals` artifact.
- **Now:** GitHub → Actions → *Update flake.lock* → *Run workflow* (on `main`), or
  `gh workflow run update-flake-lock.yml` (`-f input=nixpkgs` for one input).
- **By hand:** `bin/update/flake [--dry-run] [--input NAME]` runs `vbump run --rev
  origin/main` (any `vbump run` option passes through). It never uses the work tree:
  the base is origin/main's commit. `--dry-run` does everything except push and open.

A later run refreshes each input's PR in place. The commit is built from the base commit
and the new lock alone, so an unchanged proposal pushes the same commit again.

**Rollback to the single all-inputs PR:** set the repository variable
`FLAKE_LOCK_UPDATER=legacy` (Settings → Secrets and variables → Actions → Variables), or
dispatch with `updater: legacy`. That runs the previous `lock`/`hosts`/`diff`/`report` jobs
(one PR on `update/flake-lock`, described in §2 below). Delete the variable to return to
vbump. By hand, `UPDATE_LEGACY=1 bin/update/flake` (or a host without
`features.cli.vbump`) is the old `nix flake update` in the current branch.

## 2. Review it

A vbump PR body has the input's old and new lock (with a GitHub compare link), the other
lock nodes the update moved, a table of every host (dry build: derivations to build and
paths to fetch; package lines changed / added / removed; closure paths), each host's
version moves, and the raw `vdiff --json` reports. A host with "No diff" has a note saying
why (the base does not evaluate for it, or the diff failed); it was still evaluated and
dry-built.

A legacy PR body's **What this bump changes** section, written by the workflow's `report` job:

| Section | Look for |
|---|---|
| Flake inputs | which inputs moved; follow the *compare* links for anything surprising |
| `### <host>` NixOS / Kernel | a kernel move means a **reboot** after convergence |
| Package versions table | removals a host still needs; major-version jumps |
| "Evaluation failed" | the bump breaks that host. Don't merge. Pin or fix first |

Checks: the bump PR runs the regular `PR` workflow (`ci.yml`, with every
`nixosConfigurations` host in its check matrix), and `main` requires `ci / all-green`.
GitHub starts that workflow for the bot's PR only if the PR was opened with
`FLAKE_LOCK_UPDATE_TOKEN`. If no checks appear, **close and reopen the PR**; until then it
cannot merge.

Preview a diff locally without CI:

```bash
git worktree add /tmp/main origin/main
bin/update/pkg-diff inputs /tmp/main .
bin/update/pkg-diff host   /tmp/main . "$(hostname)"   # ~10 s, ~1 GB per host
```

Optional canary: push the branch to `testing-<hostname>`. comin applies it to that host
with `switch-to-configuration test`, and a reboot discards it.

## 3. Merge, then converge

Merge the PR by hand. That's the only step that changes hosts:

- **comin** switches every reachable host to the new `main` within 300s. Watch it with
  `curl -s http://<host>:4243/metrics | grep ^comin_` or `journalctl -u comin -n 50`.
- **Now instead of in 5 min:** `bin/fleet deploy <host>` (deploy-rs), from an
  up-to-date `main`.
- **Locally on a host:** `bin/update/host`. It refuses unless the checkout is exactly
  `origin/main` and clean, because comin would revert anything else.
  `UPDATE_ALLOW_UNMERGED=1` is for console recovery only.

**Reboot** when the notifier says *NixOS reboot pending*, or when
`comin_need_to_reboot` is 1. comin never reboots by itself.

## 4. Roll back

comin reapplies whatever `main` says, so **a durable rollback is a commit on `main`**:

```bash
git revert <bump-commit>          # or "Revert" on the merged PR
git push                          # via PR if branch protection requires it
```

All hosts return to the previous lock within 300s, or right away with `bin/fleet deploy all`.

**Immediate stopgap on one broken host**, before the revert lands:

```bash
sudo systemctl stop comin.service           # otherwise it re-applies main within 300s
sudo nixos-rebuild switch --rollback        # previous generation
# or: boot menu → previous generation, if the new one does not boot
```

Then land the revert and `sudo systemctl start comin.service`. A host left with comin
stopped is a host that no longer converges.

There is **no automatic rollback**: deploy-rs has `magicRollback = false` (see
fleet-deploy).

## 5. What tells you something is pending

`nixos-update-notifier` (user timer, 09:00 daily, desktop hosts) sends:

| Notice | Meaning | Action |
|---|---|---|
| *NixOS lock bump awaiting review* | an `update/flake-lock` PR is open (the legacy single PR; vbump's per-input `update/flake-lock-<input>` PRs are not looked up yet) | review/merge (§2–3) |
| *NixOS reboot pending* | `kernel`/`initrd`/`kernel-modules` differ from the booted system | reboot |
| *NixOS updates available* | upstream moved and no PR is open yet | run the workflow (§1) |

Run it by hand: `nixos-update-notifier --no-notify`.

## Needs operator (one-time)

See ADR-0006 § Needs operator: the `FLAKE_LOCK_UPDATE_TOKEN` secret (without it, bump PRs
are blocked on `ci / all-green` until someone closes and reopens them), or at minimum
*Allow GitHub Actions to create and approve pull requests*.
