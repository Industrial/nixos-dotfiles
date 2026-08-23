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

## Port collisions with rootless containers

A host's rootless docker/podman stack binds host ports independently of
NixOS (`rootlesskit` visible in `ss -tlnp` users). Symptom: NixOS service
crash-loops with "address already in use", or the port answers with the
WRONG app (404 from yugabyte when you expected grafana). Fix on the NixOS
side — move OUR service to a free port (check with `ss` first), never remap
the user's containers.

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
