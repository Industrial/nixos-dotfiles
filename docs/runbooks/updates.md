# Updates runbook

How the fleet takes upstream updates, and how to back one out. Policy and rationale:
[ADR-0006](../adr/0006-update-policy.md). Activation mechanics: [fleet-deploy](./fleet-deploy.md).

```
weekly cron ──► update-flake-lock.yml ──► PR "chore(flake): bump flake.lock"
                                          ├─ update-flake-lock / check (<host>)  statuses
                                          └─ PR body: inputs moved + per-host package diff
operator reviews ──► merge to main ──► comin on every host: switch (≤ 300s)
                                   └─► nixos-update-notifier: "reboot pending" if kernel moved
```

Nothing in this chain merges, reboots or switches to an unmerged tree on its own.

## 1. Get a lock-bump PR

- **Scheduled:** Mondays 03:23 UTC. If nothing moved upstream, no PR.
- **Now:** GitHub → Actions → *Update flake.lock* → *Run workflow* (on `main`), or
  `gh workflow run update-flake-lock.yml`.
- **By hand** (e.g. to bump a single input):
  ```bash
  git switch -c update/flake-lock-$(date +%F)
  bin/update/flake                       # refuses on main
  # or: nix flake update nixpkgs
  git commit -am 'chore(flake): bump flake.lock' && git push -u origin HEAD
  gh pr create --fill
  ```

There is only ever one bot PR (branch `update/flake-lock`). A later run refreshes it in place.

## 2. Review it

The PR body's **What this bump changes** section, written by the workflow's `report` job:

| Section | Look for |
|---|---|
| Flake inputs | which inputs moved; follow the *compare* links for anything surprising |
| `### <host>` NixOS / Kernel | a kernel move means a **reboot** after convergence |
| Package versions table | removals a host still needs; major-version jumps |
| "Evaluation failed" | the bump breaks that host. Don't merge. Pin or fix first |

Statuses on the PR head:

- `update-flake-lock / check (drakkar|huginn|mimir)`: `nix flake check` plus a dry-run
  toplevel build, the same action as `pr.yml`'s `check (<host>)`. muninn has a diff but
  no check (follow-up).
- `PR` workflow checks: these run only if the PR was opened with `FLAKE_LOCK_UPDATE_TOKEN`.
  Otherwise **close and reopen the PR** to start them.

Main is not fully green today. A red job on the bump PR only counts against it when the
same job is green on `main`, or fails there for a different reason.

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
| *NixOS lock bump awaiting review* | an `update/flake-lock` PR is open | review/merge (§2–3) |
| *NixOS reboot pending* | `kernel`/`initrd`/`kernel-modules` differ from the booted system | reboot |
| *NixOS updates available* | upstream moved and no PR is open yet | run the workflow (§1) |

Run it by hand: `nixos-update-notifier --no-notify`.

## Needs operator (one-time)

See ADR-0006 § Needs operator: branch protection on `main`, *Allow GitHub Actions to
create and approve pull requests*, and optionally the `FLAKE_LOCK_UPDATE_TOKEN` secret.
