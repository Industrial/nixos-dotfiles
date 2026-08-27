---
name: nixos-managing
description: Use when managing NixOS systems — rebuilding, configuring, deploying, installing, or building images. Covers flakes, modules, secret management, VM management, disk imaging, remote deployment, and common anti-patterns to avoid.
---

# NixOS Management

## Quick Decision: What do you need?

| Task | Go to |
|---|---|
| Rebuild / activate / rollback system | [vm-management.md](vm-management.md) |
| Install NixOS on new machine | [installation.md](installation.md) |
| Build ISO / disk image / VM image | [image-building.md](image-building.md) |
| Configure modules, flakes, packages, services | [configuration.md](configuration.md) |
| Ephemeral root / wipe on boot / impermanence | [impermanence.md](impermanence.md) |
| LUKS encryption / remote unlock (SSH, Tailscale) | [luks.md](luks.md) |
| Health checks / Telegram (or webhook) alerts for filesystem, disk, SMART, services | [monitoring.md](monitoring.md) |
| Something isn't working / weird behavior | [anti-patterns.md](anti-patterns.md) |

## Execution Context — Ask First

**Before suggesting any commands, establish where they will run.**

NixOS management involves multiple machines. Commands that work on the NixOS host will fail on macOS or non-NixOS Linux. Always determine the setup before suggesting commands.

**If unsure — ask:** "Where are you editing configs, and where does nixos-rebuild run?"

### All common setups

**Setup A — NixOS local (everything on one machine)**
```
NixOS machine: edit → nixos-rebuild switch (local)
```
- All commands run locally
- `nixos-option`, `man configuration.nix`, `nixos-rebuild` — all local

---

**Setup B — NixOS workstation → NixOS remote server**
```
NixOS workstation (edit) → nixos-rebuild --target-host → NixOS server
```
- `nixos-rebuild` runs on workstation, deploys to server
- Option verification: workstation (has nixpkgs) or server via SSH
- `nixos-option` on server reflects what's actually active there

---

**Setup C — macOS → NixOS remote (Linux rebuilds locally)**
```
macOS (edit .nix files) → push/rsync → NixOS Linux host → nixos-rebuild switch (local)
```
- `nixos-rebuild` runs **on the Linux host** (SSH in, or via remote trigger)
- Option verification: **SSH into Linux host** — macOS has no `nixos-option`
- `search.nixos.org/options` always works from macOS

---

**Setup D — macOS → NixOS remote (macOS drives rebuild)**
```
macOS (edit) → nixos-rebuild --target-host root@linux-host --flake .#host
```
- `nixos-rebuild` runs on macOS but activates on Linux
- Requires Nix installed on macOS (`nix` CLI, not NixOS)
- Option verification: `nix eval` works on macOS if Nix is installed; otherwise use `search.nixos.org`

---

**Setup E — Linux (non-NixOS) → NixOS remote**
```
Ubuntu/Debian/Arch (edit + run nixos-rebuild) → NixOS remote server
```
- Same as Setup D — Nix must be installed on the source machine
- `nixos-option` not available unless NixOS; use `nix eval` or `search.nixos.org`

---

**Setup F — CI/CD → NixOS remote**
```
CI agent (GitHub Actions / GitLab CI) → deploy to NixOS server
```
- CI agent needs Nix installed (use `cachix/install-nix-action` or similar)
- No interactive verification — all options must be pre-validated
- Use `nix flake check` in CI to catch errors before deploy

---

### Verification availability by machine type

| Machine | `nixos-option` | `nix eval nixpkgs#...` | `man configuration.nix` | `search.nixos.org` |
|---|---|---|---|---|
| NixOS host | ✅ | ✅ | ✅ | ✅ |
| macOS with Nix | ❌ | ✅ | ❌ | ✅ |
| Linux (non-NixOS) with Nix | ❌ | ✅ | ❌ | ✅ |
| macOS without Nix | ❌ | ❌ | ❌ | ✅ |
| CI agent with Nix | ❌ | ✅ | ❌ | ✅ |

## MCP Server: `mcp-nixos` (optional accelerator)

If the `mcp-nixos` MCP server ([utensils/mcp-nixos](https://github.com/utensils/mcp-nixos)) is configured in the environment, prefer it for lookups over SSH/web round-trips — **but ask the user first** before using it for a given task: *"I can use the mcp-nixos MCP server to look this up directly — want me to use it?"*

**What it's good at:**
- Exact **NixOS package** names, versions, metadata (130K+ packages)
- **NixOS options** (23K+) — verify option paths before suggesting config
- **Home Manager** options (5K+)
- **nix-darwin** macOS settings (1K+)
- **Nixvim** Neovim configuration (5K+)
- **FlakeHub** registry discovery (600+ flakes)
- **Noogle** Nix function lookup (2K+)
- NixOS Wiki / nix.dev documentation
- Binary cache status checks
- Local flake input exploration
- Package version history with nixpkgs commit hashes (reproducible pins)

**Use it instead of:** guessing option names, scraping `search.nixos.org`, or SSHing into a host just to run `nixos-option`. Works on macOS without Nix installed.

**Tools exposed:** `nix` (unified query), `nix_versions` (version history).

**When NOT to ask:** the user has already said they want (or don't want) to use it this session — honor that preference.

**Before installing — security review required.** Any MCP server runs with your shell privileges. Before adding `mcp-nixos` (or any MCP) to the configuration:
1. Download the source (`git clone https://github.com/utensils/mcp-nixos` or inspect the PyPI tarball via `uvx --from mcp-nixos --print` / `pip download mcp-nixos --no-deps`).
2. Review it for anything harmful: unexpected network endpoints, filesystem writes outside its own cache, shell/exec calls, credential reads (`~/.ssh`, `~/.aws`, env vars), obfuscated code, suspicious post-install hooks in `pyproject.toml` / `setup.py`.
3. Pin to a known-good version/commit rather than a floating tag.
4. Only after review — add it to the MCP config.

**Tell the user** what you reviewed and what you found before they approve the install.

## Option Verification — Always Verify Before Suggesting

**Never suggest a NixOS option from memory alone.** Option names change between NixOS versions, and incorrect options fail silently or produce confusing errors.

**Fastest path (if available):** the `mcp-nixos` MCP server — see section above. Ask the user before using it.

**Run on the NixOS host** (not macOS, not CI unless it runs NixOS):

```bash
# Search available options interactively
nixos-option services.openssh.settings

# Evaluate option existence in current nixpkgs
nix eval nixpkgs#nixosOptionsDoc --apply 'x: builtins.attrNames x' 2>/dev/null | grep -o '"[^"]*PasswordAuth[^"]*"'

# Quickest: man page on the NixOS machine
man configuration.nix | grep -A3 "PasswordAuthentication"
```

**Or use the web** (version-specific, always available):
- `https://search.nixos.org/options` — search by option name, filterable by channel
- Check the channel matching your `nixpkgs.url` (e.g. `nixos-26.05`)

**Workflow when unsure about an option:**
1. Check `search.nixos.org/options` for the option name and correct path
2. Note the NixOS version it applies to
3. Only then include it in configuration

## Module option pitfalls

- List-type module options (e.g. `services.prometheus.exporters.node.enabledCollectors`)
  **concatenate across every module import**. Two modules each setting the same
  list merge silently — per-file audits pass while the merged config is wrong.
  Always verify the evaluated merged config (`nix eval … config.<option>`) or a
  generated artifact like `config.systemd.units."<unit>".text`. Worked example:
  `nixos-deploy-rs` skill → `scripts/verify-node-exporter-flags.sh`.
- Programs using Go's flag parser reject any flag given twice
  (`error: flag 'X' cannot be repeated`) — so a duplicated list entry becomes a
  repeated CLI flag, instant exit(1), systemd start-limit-hit crash-loop.
  Same applies to a name appearing in both an enable-list and disable-list:
  NixOS renders both literally (`--collector.X` AND `--no-collector.X`).
- **Single-owner rule for shared service subtrees**: exactly one feature module
  should own a given option subtree (e.g. `prometheus-exporter` owns
  `services.prometheus.exporters.node`; the server module must not re-declare
  it). When deduplicating by DELETING one copy, check every importing host
  first — a host that imported only the deleted copy loses the setting
  entirely and silently (real case: removing the exporter block from the
  server module would have left mimir with no node-exporter at all; fix was
  adding the exporter-module import there).
- **`nix eval --apply` attr-existence checks**: the `?` operator cannot take
  a computed attribute name (`units ? (name + ".service")` is a parse error).
  Use `builtins.hasAttr (name + ".service") units` when checking generated
  per-service units in a loop.
- **`pkgs.writers.writePython3` enforces pycodestyle at BUILD time** (E401,
  E302, E501 ≤79 cols...). Embedded python scripts in modules must be
  pep8-clean or `nix flake check` / deploy fails while building the writer
  derivation — run `nix log <drv>` for the lint list when it does. Same
  class of gate exists for other writers variants.

## Core Mental Model

NixOS is **declarative and atomic**. Every change produces a new **generation**. You can always roll back.

Key workflow:
1. Edit `.nix` files
2. `git add` (in flakes — untracked files are invisible to Nix)
3. `nixos-rebuild test` (activate without committing to bootloader)
4. `nixos-rebuild switch` (set as default boot)

## Flakes vs Channels

**Use flakes** for reproducibility. Channels are impure (machine-dependent lookup paths).

Enable flakes once:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Common `nixos-rebuild` Commands

| Command | When to use |
|---|---|
| `nixos-rebuild switch` | Apply + set as default boot |
| `nixos-rebuild test` | Apply now, skip bootloader — safe first step |
| `nixos-rebuild boot` | Set as next boot without activating now |
| `nixos-rebuild dry-activate` | Preview changes without applying |
| `nixos-rebuild build` | Build only, creates `./result` |
| `nixos-rebuild build-vm` | Build QEMU VM for local testing |

Always test before switch — especially on remote servers:
```bash
nixos-rebuild test --flake .#hostname --target-host root@server
nixos-rebuild switch --flake .#hostname --target-host root@server
```

## Remote Deployment Tools

| Tool | Best for |
|---|---|
| `nixos-rebuild --target-host` | 1-3 machines, simplest |
| `deploy-rs` | Small fleet, auto-rollback on failure |
| `colmena` | Large fleet, parallel, cross-host config |
| `nixos-anywhere` | Initial install on non-NixOS machine |

## Secret Management

| Tool | When to use |
|---|---|
| **agenix** | Simple setup, SSH key workflow, small secret count |
| **sops-nix** | Cloud KMS needed, templating, multiple formats |

Secrets live at `/run/agenix/` or `/run/secrets/` — never in Nix store.

## Most Frequently Changed Elements

- `environment.systemPackages` — installed packages
- `users.users.<name>` — user accounts and SSH keys
- `networking.*` — hostname, IPs, firewall ports
- `services.*` — enable/configure systemd services
- `boot.loader.*` — bootloader and kernel settings
- `nix.settings.*` — substituters, trusted users, features
- **Python version**: `python313` is recommended (avoids docutils 0.23 `TypeError` crash in `python3.12-doc`); `python312` is available but avoid `python3.12-doc` which pulls the buggy docutils version)

See [configuration.md](configuration.md) for patterns.

## Service health: unit state lies, probe the port

`systemctl is-active <unit>` is insufficient evidence in both directions:
- oci-container units (virtualisation.oci-containers) report `inactive`
  while the container serves fine — verify by HTTP probe instead.
- .NET apps (readarr) go `active` before they listen — sleep, then probe.
- A unit can stay `failed` across many deploys because switch does not
  restart unchanged units (real case: grafana failed on a port collision at
  first enable; every later deploy "confirmed" while the dashboard was down).
Smoke-check pattern after any deploy:
`systemctl is-active <unit>` + `curl -s -o /dev/null -w "%{http_code}"
http://127.0.0.1:<port>/` — any code <500 (200/302/307) means the app is up.

## Crash-loop triage shortcuts

- "Core dumps" reported on a host are often NOT coredumps: Node/V8 aborts
  embed full multi-thread stack traces directly in the journald stream
  while `coredumpctl list` stays empty and
  `/var/lib/systemd/coredump/` has nothing. Run coredumpctl FIRST to
  classify before hunting for core files.
- Unauthenticated `api.github.com` callers (icon updaters, release
  watchers) crash-loop when the SHARED egress IP exhausts the anonymous
  60 req/hour quota: repeating SIGABRT/assertion failures every RestartSec
  with a 403 JSON body nearby in the journal. Confirm with
  `curl -sI https://api.github.com/repos/<any>` →
  `x-ratelimit-remaining: 0`; epoch `x-ratelimit-reset` says when it
  self-heals. Durable fix is a token injected into the unit's environment
  — not faster restarts or more RAM. Worked case: mimir's homarr-tasks,
  see nixos-fleet-management → references/mimir-media-stack.md.
- A unit can sit active-but-crash-looping for hours with zero host-level
  distress (no OOM kills, normal load, plenty of free RAM) and still not
  appear in `systemctl --failed` between restarts — grep the unit's
  journal (`journalctl -u <unit> | grep -c <signature>`) instead of
  trusting status headers.
- Quota-budgeted restart design when the token fix isn't available yet:
  size `RestartSec` so failed-starts-per-hour × requests-per-start stays
  well under the quota window (a 5s loop doing 3 GitHub calls per start
  burns ~2100 req/h — self-starving), then arm an hourly revive timer via
  `ExecStartPost = "+${pkgs.systemd}/bin/systemctl start <name>-revive.timer"`
  (leading `+` runs as root; every successful start re-arms the timer).
  Worked example: features/media/homarr/default.nix (commit 38c22740).
- Root-owned state files: any state created by a root-run process
  (manual migrate run, pre-module deploy) keeps root ownership while the
  unit runs as a service user — symptom is
  `SqliteError: attempt to write a readonly database` / permission
  errors with the unit showing active. tmpfiles rules only create FRESH
  dirs; existing state needs a one-time
  `chown -R <user>:<group> <state-dir>` + unit restart. Always
  `stat -c "%U:%G"` DB/state paths when a service logs
  permission-flavored errors. **chown alone is never the finish line:**
  restart EVERY unit consuming the repaired state — live processes hold
  open handles/prepared statements against the OLD inode, and native
  modules abort at GC/shutdown instead of failing cleanly (real case:
  better-sqlite3 `Statement::~Statement()` →
  `node::RemoveEnvironmentCleanupHook` assertion killed the web unit
  ~30 s after the DB under it was chowned; a clean restart fixed it).
- Long `RestartSec` trade-off: throttling a crash loop to e.g. 20 min
  means the unit dwells in `activating (auto-restart)` after each
  failure — recovery needs an explicit `systemctl start <unit>`, and
  `NRestarts` stays deceptively low. Don't read the dwell as a hang;
  check `SubState=auto-restart` and just start it when repairing.
  Note: `systemctl start` on a host whose login shell is nushell fails
  with "requires interactive authentication" over non-tty ssh — use
  `ssh -t <host> "sudo systemctl start <unit>"` for privileged starts.
- authjs/NextAuth apps (Homarr, many dashboards) REQUIRE `AUTH_SECRET`
  in production env: missing it yields `MissingSecret` error per tRPC
  request + HTTP 500 pages while systemctl shows active/healthy. When
  a Node dashboard serves 500s, grep the unit journal for MissingSecret
  before touching app config.
- Native-module crash signature vs app bug: when a Node service dies
  with `Assertion failed: (env) != nullptr` in
  `node::RemoveEnvironmentCleanupHook` reached from a native addon
  destructor (e.g. `Statement::~Statement()` in better-sqlite3), suspect
  an ABI/native-version mismatch or stale handles — not the JS code.
  It fires at GC/shutdown, seconds AFTER healthy startup, so logs look
  like a working service that randomly dies. Triage: read the DB with a
  small script (readonly) to rule out corruption, then check which Node
  major the addon was built against; fix = rebuild the package against a
  compatible Node (pin nodejs_22) or bump the addon — never chase it as
  an app-config problem.
- Container-first upstream apps: don't vendor source builds. If an app
  publishes only an OCI image and no bare-metal support, packaging its
  source re-introduces exactly this native-module coupling (real case:
  vendored homarr build SIGABRT-looped on mimir via better-sqlite3 under
  Node 24 despite fixes to env/secrets/state; endgame was reverting the
  whole feature module to the official image via
  `virtualisation.oci-containers`). Reserve source builds for apps that
  genuinely support them; treat "works as container" as the baseline.
- Inspecting a service's sqlite DB without a sqlite3 binary: run the
  service's OWN bundled driver as the service user — write a tiny JS
  file, scp it to the host, chmod 644 (service user can't read root's
  umask), then
  `sudo -u <svc> <store-path-node>/bin/node /tmp/script.js`. Readonly
  open (`new Database(path, {readonly: true})`) is safe against live
  units. This answers "is the data corrupt or just unreferenced?" in one
  step. For OCI containers, `podman cp` the script in and run it with the
  image's own node (`podman exec <ctr> node /tmp/s.js`); container /tmp is
  wiped on restart, so re-copy every session.
- **Ad-hoc verification of module changes** (when the system asks for
  evidence beyond the suite): write `/tmp/hermes-verify-<topic>.sh` that
  (1) evals the module with stubbed deps via
  `nix eval --impure --json --expr` and asserts invariants with `jq`,
  (2) runs the colocated assay file only, (3) checks worktree==HEAD for
  the changed paths, (4) SSHes for live-state probes.   Summarize as
  "ad-hoc, not suite green". Gotchas: `nix-instantiate --eval --json`
  chokes on thunks (use `nix eval --impure`), python3 may be absent on
  NixOS (use jq), uv-managed pythons fail on NixOS dynamic linking. If the
  operator denies EXECUTING the verify script, do not retry it — degrade to
  single-purpose read-only probes (ssh cat piped to local diff, targeted
  greps); they cover the same ground and match the step-watching
  preference. Leave the script in /tmp unless deletion is separately
  approved.


## Remote shells are nushell

Fleet hosts have nushell as login shell: bare `&&`, `2>/dev/null`,
`${var}` interpolation, and string-pipeline commands all fail or misparse
over plain `ssh <host> '<cmd>'`. Wrap compound remote commands as
`ssh <host> "bash -c '...'"` (mind quoting depth — nested `\"` inside
the bash -c string breaks substitution). Locally, lean-ctx's shell
allowlist blocks `ssh` permanently ([BLOCKED] = don't retry there); use
the Hermes terminal tool for SSH sessions instead.

## Declarative app-config round-trip (git spec ↔ live state)

For "keep the app's config in git, but let UI edits persist" work —
spec file + `<app>-sync` oneshot + timer-driven `<app>-export` diff-refresh.
Covers symlink vs in-container-reconciler transports, secret placeholder
handling, schema introspection before writing rows. Full pattern,
pitfalls and verification shape:
[references/declarative-app-config-roundtrip.md](references/declarative-app-config-roundtrip.md)

## Port collisions with rootless containers

A host's rootless docker/podman stack binds host ports independently of
NixOS (`rootlesskit` visible in `ss -tlnp` users). Symptom: NixOS service
crash-loops with "address already in use", or the port answers with the
WRONG app (404 from yugabyte when you expected grafana). Fix on the NixOS
side — move OUR service to a free port (check with `ss` first), never remap
the user's containers.

## Restoring a module from git history: re-check ports and neighbors first

Old module code carries OLD assumptions. When reviving a deleted feature
(`git show <rev>^:<path>` after locating it via
`git log --all --diff-filter=D -- "*<name>*"`), before deploying:

1. **Verify the configured port is still free** — services drift; a 2024-era
   `listenPort = 8080` collided with qbittorrent-nox's WebUI that now owns
   it (EADDRINUSE → restart loop → start-limit-hit, unit lands `failed`
   within seconds of activation). `sudo ss -tlnp | grep :<port>` on the
   target host first; pick a fresh port and update the assay.
2. Check the journal for `EADDRINUSE` immediately post-deploy — it's the
   signature of exactly this stale-port class.
3. Add dashboard/tile links for whatever NOW occupies the old port so the
   moved service stays discoverable.
4. Rewrite any stale assay assertions (old port values, old descriptions)
   in the same commit.

Worked case: homepage-dashboard restored on mimir at 8083
(commits 8f501e36 + 4b7ea498).

## Assay (colocated `*.assay.nix`) conventions

- Stub `pkgs` with the EXACT attr names the module's `with pkgs;` block
  references — hyphens included (`{qbittorrent-nox = "qbittorrent-nox";}`).
  A wrong key is an eval-time `undefined variable`, and because suites load
  repo-wide it blocks every commit until fixed.
- A module import in a test must supply EVERY argument the module declares:
  `{config, lib, pkgs, ...}` needs `config = {}; lib = {};` passed even when
  unused ("function called without required argument").
- Host-config assays assert what is CURRENTLY imported (e.g. fleet
  remote-access, real profiles). When a cleanup commit deletes a profile,
  update its host assay in the same change or the suite fails stale.

## Committing in this repo (devenv + prek hook gauntlet)

Hooks are `devenv shell -- <entry>` wrappers (moon test/assay, commitizen,
pre-commit, deepsec pre-push). Plain `git commit` fails with
`No such file or directory` because hook entries (e.g. bare `pre-commit`)
only exist inside devenv — **always commit via `devenv shell -- git commit …`**.

- Commitizen enforces Conventional Commits (`fix:`, `feat:`, `test:`,
  `chore:` scopes like `(monitoring)` / `(nixos)` match repo history).
- prek evaluates the **exact staged tree**, stashing everything else: a
  pathspec-limited commit of fix N runs the suite against HEAD-with-fix-N-only.
  If earlier broken-in-HEAD suites exist, land their repair FIRST as its own
  `test:` commit, then the functional change.
- The repo's canonical gate is `devenv shell -- assay run .`
  (540 suites at last count) plus `nix flake check`.
- Operator preference: do NOT bundle unrelated cleanup (`rm`, etc.) into a
  verification or commit command — issue single-purpose commands; compound
  commands were denied twice this session.
- **Index hygiene**: this repo often carries unrelated PRE-STAGED files
  (e.g. `features/ai/hermes-agent/.hermes/*`). A bare `git commit` — and
  especially `git commit --amend` — sweeps all of it into your commit.
  Always pass an explicit pathspec, and after any commit/amend run
  `git show --stat HEAD` to confirm exactly what landed. If foreign files
  got swept: `git reset --soft HEAD^` (safe while unpushed), re-commit with
  pathspec; the index keeps the foreign staging untouched.
- **Verify the committed tree, not a dirty worktree**: when the worktree
  carries unrelated changes, evaluation against it proves nothing about
  HEAD. `git worktree add /tmp/hermes-verify-head-worktree HEAD`, run the
  checks there (adjust any script's REPO path first), then remove it.
  Evidence about HEAD outranks evidence about a worktree.
- **Untracked files are invisible to flake evals** (`error: Path '...' is
  not tracked by Git`): a brand-new module file fails deploy/eval until
  `git add`ed — the fix is staging the file, not changing the code.
- **Worktree `cd` trap**: terminal state persists across calls — a leftover
  `cd /tmp/<worktree>` from verification makes every LATER command (deploys,
  evals) run against the stale snapshot silently. Real case: a deploy
  "confirmed" while shipping the old config because bin/fleet resolved ROOT
  inside a throwaway worktree. Pin `workdir` explicitly on every command, or
  cd back immediately after worktree checks; if a stale deploy slipped
  through, redeploy from the real tree before trusting any result.
