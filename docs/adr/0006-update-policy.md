# ADR-0006: Update policy — lock bumps by reviewed PR, convergence by comin

**Status:** Accepted
**Date:** 2026-11-20
**Issue:** Industrial/nixos-dotfiles#117
**Builds on:** [ADR-0001](./0001-fleet-deploy-rs.md) (deploy-rs), [ADR-0002](./0002-comin-pull-convergence.md) (comin)

> Numbering note: #125 also adds an ADR-0006. Whichever of the two merges second
> renumbers; nothing depends on the number except the comments that cite it.

## Context

Before this ADR, updates had three halves, none of them connected:

- **Lock bumps by hand.** `bin/update/flake` ran `nix flake update` in whatever branch
  the operator's checkout was on, with no review, no host check and no record of what moved.
  The lock simply went stale between remembered bumps.
- **A dead unattended path.** `features/nixos/auto-update` carried a nightly root timer
  (`nix flake update` + `nixos-rebuild switch`). It was hard-disabled, because root cannot
  update a user-owned git flake, and a nightly switch fights interactive sessions and RAM.
- **Local switches.** `bin/update/host` → `bin/update/system` switched the host to its
  local working tree. Since ADR-0002, comin switches every host back to `origin/main` within
  300s, so a local switch of anything else is reverted, or survives only while comin is
  stopped. That's a second source of truth.

`nixos-update-notifier` ran daily, but it reported only "upstream moved". It didn't report
the two things only the operator can act on: a bump waiting for review, and a reboot
after comin has already switched kernels.

## Decision

1. **`origin/main` is the only state any host converges to.** This was already true for
   comin (ADR-0002). It now holds for every path:
   - comin `switch` from `main` is the unattended activator;
   - `bin/fleet deploy` (deploy-rs) is the operator's immediate activator, run *after* pushing;
   - `bin/update/system` refuses unless `HEAD == origin/main` and the tracked tree is clean
     (`UPDATE_ALLOW_UNMERGED=1` covers console recovery);
   - `features/nixos/auto-update` is now a guard. It asserts `system.autoUpgrade.enable`
     is false, so nixpkgs' upgrader can't become a third activator.
2. **Lock bumps arrive as pull requests.** `.github/workflows/update-flake-lock.yml` runs
   weekly (Mon 03:23 UTC) and on demand. It uses `DeterminateSystems/update-flake-lock`,
   pinned to a commit SHA, to open or refresh one PR from `update/flake-lock`.
   `bin/update/flake` is the by-hand equivalent and refuses to bump on `main`.
3. **Every lock-bump PR carries its own evidence:**
   - The regular PR workflow (`pr.yml` → `ci.yml`), with its host matrix generated from
     `nixosConfigurations` and the required `ci / all-green` gate. Host checks are not
     duplicated in the bump workflow.
   - A PR-body table of root inputs that moved, with GitHub compare links.
   - A per-host diff for every `nixosConfigurations` entry: NixOS release, kernel version and
     `environment.systemPackages` versions. It comes from `bin/update/pkg-diff` (logic in
     `bin/update/lib/pkg-diff.nix`, with an assay suite). An evaluation failure shows up
     in the PR body and fails the job.
4. **Nothing merges automatically.** The workflow doesn't approve, merge or enable
   auto-merge. The operator reviews and merges, and comin applies the change fleet-wide
   within ~5 minutes. Optionally, push to `testing-<hostname>` first to try one host.
5. **"Green main" is enforced at the merge gate, not on the hosts.** comin can't tell
   whether a commit was green, so the guarantee has to hold before the commit reaches
   `main`. That's branch protection on `main` requiring `ci / all-green` (in place since
   #126), which covers every host check.
6. **The notifier reports what's pending on the operator.** On a schedule
   `nixos-update-notifier` reports:
   - any open `update/flake-lock` PR, through the unauthenticated GitHub API on this
     public repo. While one is open, it skips its local build, since the PR has the diff;
   - a pending reboot, when `kernel`, `initrd` or `kernel-modules` differ between
     `/run/booted-system` and `/run/current-system`;
   - otherwise, upstream movement with the exact built `nix store diff-closures` package
     list, when RAM allows.
7. **Rollback is a revert on `main`.** comin reapplies whatever `main` says, so the
   durable rollback is `git revert` of the bump commit (or reverting the PR in the UI).
   An on-host `nixos-rebuild switch --rollback` is the immediate stopgap and lasts only
   until comin's next poll, unless comin is stopped first. The procedure is in
   `docs/runbooks/updates.md`.

## Amendment (2026-11-21, GH-189): one PR per input, by vbump

Decision 2 now runs `vbump` (rust/tools/vbump, Voltaic + id_effect) instead of
`DeterminateSystems/update-flake-lock`. For each root input on its own, it runs
`nix flake update <input>` (C++ Nix stays the lock resolver), evaluates and dry-builds
every `nixosConfigurations` host against that lock (`--reference-lock-file` on the base
commit), diffs each host's toplevel **derivation** closure against `main` with vdiff's
`--json` report, and opens or refreshes one PR per input on `update/flake-lock-<input>`.
An input that does not evaluate or dry-build gets no PR and fails the run; it never blocks
another input's PR. Decision 3's evidence is now per input: the dry build and the
derivation-closure diff replace the evaluated `systemPackages` diff. A derivation closure is
known without building, and every package's version move is in it.
`bin/update/flake` runs the same `vbump run` by hand.

Rollback: the repository variable `FLAKE_LOCK_UPDATER=legacy` (or the dispatch input
`updater: legacy`) runs the previous single all-inputs PR job unchanged. The selector is
covered by `features/cli/vbump/default.assay.nix`. Decisions 1 and 4 to 7 are unchanged:
nothing merges on its own.

## Why the PR shows evaluated versions, not a built closure diff

A real closure diff (`nix store diff-closures`, nvd) needs both closures realised for each
of four hosts. That doesn't fit a GitHub runner's disk or time, and building locally is ruled
out on this RAM-shared box. The evaluated package set costs about 10 s and 1 GB per host.
It names every line a reviewer actually looks at: package versions, kernel and release.
The built diff still exists, on the host after merge, through the notifier.

## Consequences

**Positive**
- The lock no longer goes stale silently. A bump is proposed every week, with evidence.
- No unreviewed lock reaches a host. Every activation path converges on `main`.
- A kernel update no longer goes unnoticed until the next reboot.

**Negative**
- With the default `GITHUB_TOKEN`, GitHub doesn't start `pr.yml` for the bot's PR, so the
  required `ci / all-green` never runs and the PR **can't merge**. Until a
  `FLAKE_LOCK_UPDATE_TOKEN` secret exists, someone has to close and reopen each bump PR to
  start CI.
- `bin/update/system` now needs a network fetch, and refuses dirty trees.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| `system.autoUpgrade` on each host | A third activator. It converges to an unreviewed upstream, not to `main`, and fights comin every poll |
| Re-enable the nightly root timer | Same as above, plus root vs. user-owned flake failure and RAM contention |
| Auto-merge green bump PRs | Main is not reliably green yet, and the operator wants to read kernel/package moves before the fleet takes them |
| Renovate / Dependabot for flake.lock | Extra third-party app with broader permissions, and still no per-host NixOS diff |
| Build closures in CI for nvd | Doesn't fit runner disk/time for four desktop/server closures. Evaluated diff plus on-host built diff covers the need |

## Needs operator

- **`FLAKE_LOCK_UPDATE_TOKEN` repo secret** (fine-grained PAT or GitHub App token,
  `contents: write` and `pull-requests: write` on this repo). `main` requires
  `ci / all-green`, and GitHub won't run it on a PR opened with `GITHUB_TOKEN`. Without this
  secret, every bump PR is blocked until a person closes and reopens it.
- Settings → Actions → General → Workflow permissions: enable **"Allow GitHub Actions to
  create and approve pull requests"**. Without it, the `lock` job can't open the PR with
  `GITHUB_TOKEN`. That setting isn't needed once the token above is set.
