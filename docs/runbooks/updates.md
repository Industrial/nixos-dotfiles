# Updates runbook

How the fleet takes upstream updates, and how to back one out. Policy and rationale:
[ADR-0006](../adr/0006-update-policy.md). Activation mechanics: [fleet-deploy](./fleet-deploy.md).

```
weekly cron ──► vbump.yml ──► vbump: per input, PR "chore(flake): bump <input>", auto-merge armed
                              ├─ PR workflow → ci.yml → ci / all-green  (required)
                              └─ PR body: the input's lock move + per-host
                                 dry build and closure diff (vdiff --json)
ci / all-green passes ──► PR squash-merges itself ──► comin on every host: switch (≤ 300s)
                                                  └─► nixos-update-notifier: "reboot pending" if kernel moved
```

vbump is the only lock updater (GH-247). Each bump merges itself once the required
`ci / all-green` passes (user decision, 2026-11-23); CI, and after the merge vdeploy's
health check and rollback, are the gate. Nothing in this chain reboots, or switches a host
to an unmerged tree. To hold one bump, disable auto-merge on its PR (or close it).

## 1. Get lock-bump PRs

- **Scheduled:** Mondays 03:23 UTC. `vbump` (rust/tools/vbump, GH-189) takes each root
  input on its own: `nix flake update <input>`, evaluate and dry-build every
  `nixosConfigurations` host against that lock, diff each host's derivation closure against
  `main`, open or refresh one PR per input on `update/flake-lock-<input>`, and arm
  auto-merge (squash) on it (`--auto-merge`; an input whose auto-merge cannot be armed
  fails, so the run goes red). An input
  that did not move gets no PR. An input that does not evaluate or dry-build on some host
  gets no PR and turns the run red; the other inputs still get theirs. The run's summary
  table is on the workflow run page, and every PR body and `vdiff --json` report is in its
  `vbump-proposals` artifact.
- **Now:** GitHub → Actions → *Update flake.lock (vbump)* → *Run workflow* (on `main`), or
  `gh workflow run vbump.yml` (`-f input=nixpkgs` for one input).
- **By hand:** `bin/update/flake [--dry-run] [--input NAME] [--auto-merge]` runs `vbump run
  --rev origin/main` (any `vbump run` option passes through). It never uses the work tree:
  the base is origin/main's commit. `--dry-run` does everything except push and open; a
  by-hand run arms auto-merge only with `--auto-merge`.

A later run refreshes each input's PR in place. The commit is built from the base commit
and the new lock alone, so an unchanged proposal pushes the same commit again.

**Rollback (the one option): restore the old workflow from git history.** GH-247 deleted
`.github/workflows/update-flake-lock.yml` (its legacy `lock`/`hosts`/`diff`/`report` jobs
opened one all-inputs PR on `update/flake-lock`) and the whole-lock fallback of
`bin/update/flake`. In a PR:

```bash
git rm .github/workflows/vbump.yml
git checkout 056a7031988ab79b639c9d2c0b5fddadbadf22e0 -- .github/workflows/update-flake-lock.yml bin/update/flake
```

`056a7031` is the last `main` commit with both. Restored, that workflow runs vbump
*without* auto-merge by default, and the repository variable `FLAKE_LOCK_UPDATER=legacy`
then selects its single all-inputs PR; `UPDATE_LEGACY=1 bin/update/flake` is the old local
`nix flake update` again. `bin/update/pkg-diff` (which the legacy jobs call) is kept for
that. To stop only the auto-merge, drop `--auto-merge` from vbump.yml's *Bump each input*
step instead. `features/cli/vbump/default.assay.nix` checks that exactly one lock updater
exists and that this rollback is the one written here.

## 2. Review it

A vbump PR body has the input's old and new lock (with a GitHub compare link), the other
lock nodes the update moved, a table of every host (dry build: derivations to build and
paths to fetch; package lines changed / added / removed; closure paths), each host's
version moves, and the raw `vdiff --json` reports. A host with "No diff" has a note saying
why (the base does not evaluate for it, or the diff failed); it was still evaluated and
dry-built.

Reading it is optional: the PR merges itself when green. Look when you want to know what a
bump moves, and hold it (disable auto-merge) if a move is unwanted.

Checks: the bump PR runs the regular `PR` workflow (`ci.yml`, with every
`nixosConfigurations` host in its check matrix), and `main`'s ruleset requires
`ci / all-green`; auto-merge waits for it. GitHub starts that workflow for the bot's PR
only if the PR was opened with a token other than `GITHUB_TOKEN`: the vbump app's per-run
token (§6). If no checks appear (a run without the app says so at the top of its job
summary), **close and reopen the PR**; until then it cannot merge.

On drakkar, vci (`features.nix.vci`) also builds every open PR's hosts and can post
`vci/<host>` commit statuses on it (§7). They are informational: they are not required
checks, and auto-merge does not wait for them.

Preview a diff locally without CI:

```bash
git worktree add /tmp/main origin/main
bin/update/pkg-diff inputs /tmp/main .
bin/update/pkg-diff host   /tmp/main . "$(hostname)"   # ~10 s, ~1 GB per host
```

Optional canary: push the branch to `testing-<hostname>`. comin applies it to that host
with `switch-to-configuration test`, and a reboot discards it.

## 3. Merge, then converge

The PR squash-merges itself once `ci / all-green` passes (a non-bump PR is merged by
hand). The merge is the only step that changes hosts:

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
| *NixOS lock bump awaiting review* | a lock-bump PR is open: any of vbump's per-input `update/flake-lock-<input>` PRs (GH-200; or a restored legacy `update/flake-lock` PR) | nothing: it merges itself when green; read it if you like (§2) |
| *NixOS reboot pending* | `kernel`/`initrd`/`kernel-modules` differ from the booted system | reboot |
| *NixOS updates available* | upstream moved and no PR is open yet | run the workflow (§1) |

Run it by hand: `nixos-update-notifier --no-notify`.

## 6. The vbump GitHub App (one-time setup)

The `vbump` job mints a short-lived installation token at the start of each run with
`actions/create-github-app-token`. The token is scoped to this repository and to the
three permissions below, and it is revoked when the job ends. The job uses it for the
branch pushes, the PRs, the label and arming auto-merge (contents and pull requests write
are what auto-merge needs). Because the token is not `GITHUB_TOKEN`, each bump PR's
`ci / all-green` starts on its own. Without the two secrets, the job falls back to
`GITHUB_TOKEN`, with a warning.

The app exists (2026-11-23): `vbump-nixos-dotfiles`, app id 5886494, installed on this
repository only, with Contents, Pull requests and Issues **Read and write** and Commit
statuses **Read and write** (for vci, §7). The steps below are how it was made, and how to
make it again.

1. **Create the app.** As **Industrial**, open GitHub → Settings → Developer settings →
   GitHub Apps → **New GitHub App** (<https://github.com/settings/apps/new>) and fill in:
   - **GitHub App name:** `vbump-nixos-dotfiles` (any unique name; it shows as
     `<name>[bot]` on the PRs and commits).
   - **Homepage URL:** `https://github.com/Industrial/nixos-dotfiles`.
   - **Webhook:** untick **Active**. The app receives no events.
   - **Repository permissions:** Contents **Read and write**, Pull requests **Read and
     write**, Issues **Read and write** (for the `flake-lock` label). Metadata **Read-only**
     is selected automatically. Leave every other permission at *No access*, and set no
     organization or account permissions.
   - **Where can this GitHub App be installed?** **Only on this account**.
   - Click **Create GitHub App**.
2. **Note the Client ID** shown on the app's page (`Iv…`). The numeric **App ID** works too.
3. **Generate a private key.** On the same page, under **Private keys**, click **Generate a
   private key**. A `.pem` file downloads.
4. **Install it on this repository only.** Open the app's **Install App** tab, then
   **Install** on Industrial, choose **Only select repositories**, and pick
   **Industrial/nixos-dotfiles**.
5. **Add the two secrets.** In Industrial/nixos-dotfiles, open Settings → Secrets and
   variables → Actions → **New repository secret**:
   - `VBUMP_APP_ID`: the Client ID (or App ID) from step 2;
   - `VBUMP_APP_PRIVATE_KEY`: the whole `.pem` file, including the `-----BEGIN` and
     `-----END` lines.

   Then delete the local `.pem` file. GitHub keeps only the public half.
6. **Check it.** Run `gh workflow run vbump.yml`. The *Mint the vbump app token* step
   runs, the job summary has no warning, and the new PRs and commits are by `<name>[bot]`
   with their checks started and auto-merge armed.

Rotate the key by generating a second key, replacing `VBUMP_APP_PRIVATE_KEY`, then
deleting the old key on the app page. Revoke all access by uninstalling the app; the job
then falls back, as above.

## 7. vci's per-host statuses on drakkar (optional, off by default)

vci builds every open PR for every host on drakkar. With a token it posts a `vci/<host>`
commit status on each (pending, then success or failure with the closure summary). The
token is an installation token of the vbump app, minted on drakkar by `vci-token`
(`rust/tools/vci`, the second binary): it reads the app's private key from a root-only
file through systemd `LoadCredential`, mints a token narrowed to *Commit statuses: write*
every 30 minutes (tokens last an hour; an id_effect Schedule, failures retried), and
writes it to `/run/vci-token/token`, which only the `vci` group reads. It is off until the
option `features.nix.vci.statusApp.privateKeyFile` is set. The statuses are not required
checks.

To turn it on (the user's steps; an agent does none of them):

1. **Generate a second private key** for the app: GitHub → Settings → Developer settings
   → GitHub Apps → `vbump-nixos-dotfiles` → **Private keys** → **Generate a private key**.
   A `.pem` file downloads. (The first key stays in the `VBUMP_APP_PRIVATE_KEY` secret; a
   second key can be revoked on its own.)
2. **Place it on drakkar, root-only:**
   ```bash
   bash -c 'sudo install -D -m 0400 -o root -g root ~/Downloads/vbump-nixos-dotfiles.*.private-key.pem /var/lib/secrets/vbump-app.pem && shred -u ~/Downloads/vbump-nixos-dotfiles.*.private-key.pem'
   ```
3. **Set the option** in `hosts/drakkar/configuration.nix`, in a PR:
   ```nix
   features.nix.vci.statusApp.privateKeyFile = "/var/lib/secrets/vbump-app.pem";
   ```
   (`statusApp.appId` defaults to the app's id, 5886494.) comin deploys it after the merge.
4. **Check it** (no root needed): `systemctl is-active vci-token`, `stat -c '%U:%G %a'
   /run/vci-token/token` (`vci-token:vci 440`), and a `vci/drakkar` status on the next
   PR vci builds.

Rotate: generate a new key, replace the file the same way, `sudo systemctl restart
vci-token`, then delete the old key on the app page. Turn it off: unset the option.

## Needs operator (one-time)

Nothing for the bump PRs: the vbump app (§6) is set up. Optional: vci's statuses (§7).
