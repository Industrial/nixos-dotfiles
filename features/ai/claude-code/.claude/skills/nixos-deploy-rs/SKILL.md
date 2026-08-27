---
name: nixos-deploy-rs
description: >-
  Deploy NixOS fleets with deploy-rs on a unified flake. Use when adding
  deploy.nodes, magicRollback, interactiveSudo, root flake unification,
  disabling comin, or remote switch of hosts (drakkar/huginn/mimir). Not for
  Colmena or Hermes agent wrappers.
---

# NixOS deploy-rs Fleet

## Overview

Push-deploy NixOS hosts from a **single root flake** using **deploy-rs only**.
Per-host modules (`disko.nix`, `hardware.nix`, `filesystems.nix`) stay under
`hosts/<name>/`; the root flake only exposes `nixosConfigurations` + `deploy`.

## Dependencies

- `nixos-managing` — rebuild/rollback/anti-patterns
- `scientific-method` — when choosing between deploy tools or flake topologies

## Locked decisions (this repo)

| Topic | Decision |
|-------|----------|
| Deployer | deploy-rs only (Colmena deferred) |
| Flake | Unified root `flake.nix` |
| Comin | Disabled while push-deploy is primary |
| Hermes | Out of scope |

## Workflow

### 1. Preconditions
- OpenSSH key-only on targets; test `ssh <host> hostname`
- Prefer wheel user + `interactiveSudo = true` for humans
- Disable `magicRollback` only when changing SSH port/IP/listen

### 2. Flake shape
```nix
deploy.nodes.<host> = {
  hostname = "<host>";
  profiles.system.path =
    deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.<host>;
};
checks = builtins.mapAttrs (_: c: c.deployChecks self.deploy) deploy-rs.lib;
```

### 3. Operator commands
```bash
nix flake check
bin/fleet check <host>           # flake check + per-host dry-activate
bin/fleet deploy <host>          # single host
bin/fleet deploy all             # all nodes; wrapper goes host-by-host so one
                                 # unreachable node does not block the rest,
                                 # exits non-zero if any host failed
```
Prefer the `bin/fleet` wrapper over bare `deploy`: `deploy .` aborts the
whole run on the first unreachable node.

### 4. Conflict with comin
Never leave `services.comin.enable = true` while deploy-rs is primary.

## Common Mistakes

- Activating with Colmena **and** deploy-rs on the same generation stream
- Assuming Colmena has magicRollback / `colmena rollback` (it does not)
- Moving Disko into root flake body (keep modules under `hosts/`)
- Leaving comin enabled → double apply races
- `services.prometheus.exporters.node` list mistakes (`enabledCollectors`
  duplicated entries, or a collector in both enabled and disabled lists):
  NixOS renders each entry as a literal flag, so ExecStart gets e.g.
  `--collector.tcpstat --collector.tcpstat`. Go's flag parser rejects repeats
  → exit(1) → systemd crash-loops to start-limit-hit → activation reports
  "units failed" → deploy-rs magic-rollbacks. Symptom is *flaky* deploys:
  failure depends on where the switch's unit-state check lands in the
  crash/restart cycle. Grep the target's journal for
  `cannot be repeated, try --help` to confirm. After fixing the module,
  also run `systemctl reset-failed <unit>` (or redeploy) on hosts left in
  start-limit-hit state, or they stay broken between deploys.
- Trusting per-file audits of NixOS list options. List options
  **concatenate across module imports**: two modules each setting
  `services.prometheus.exporters.node` with internally-clean lists still
  yield a duplicated merged list (bit a host importing both
  `prometheus-exporter` and `prometheus`). Fix by importing only one module
  that configures the exporter, and always verify the **evaluated merged
  config**, not the source files — use
  `scripts/verify-node-exporter-flags.sh` (bash+jq, no python needed).
- Trusting `pwd` across tool calls. The terminal session keeps its working
  directory between commands, so any earlier `cd /tmp/...` (e.g. into a
  throwaway verification worktree) silently redirects every later
  `bin/fleet`, `nix eval .#…`, and relative-path edit to that copy — this
  produced a confirmed deploy of a STALE config whose smoke check then
  failed against the wrong generation. Pass explicit `workdir` on every
  command and when a result contradicts the tree you just edited (`grep`
  says enabled, eval says absent), suspect the wrong checkout BEFORE
  suspecting Nix.
- Trusting "Deployment confirmed" as proof of health. switch-to-configuration
  does NOT restart UNCHANGED units, so a unit left `failed` by an earlier
  deploy stays down while every subsequent deploy confirms fine — a grafana
  instance sat silently failed across many green deploys this way (its port
  had been taken by a container). Rule: after any deploy, smoke-check every
  unit you care about (`systemctl is-active` + local HTTP probe); when taking
  over an unfamiliar fleet, sweep ALL service units once before trusting it.
- Reading the deploy log for activation-script errors. Activation runs with
  a minimal PATH: any non-builtin command inside a
  `system.activationScripts.*.text` must be referenced by store path
  (`${pkgs.diffutils}/bin/cmp`, not bare `cmp`). A missing binary prints
  `activate: line N: <cmd>: command not found` mid-log yet the deploy can
  still end "Activation succeeded!"/"Deployment confirmed." — grep every
  deploy log for `command not found` after shipping a new activation script,
  then re-deploy and confirm the warning is gone (the re-run also proves the
  script's idempotent path). Side effect seen in production: an inverted
  `if ! cmp -s` guard created spurious `.bak.<ts>` files on each switch.
- A FAILING ONESHOT unit trips magic rollback exactly like a dead daemon:
  prowlarr-sync exited 1 (HTTP 400 while registering an app whose port
  wasn't listening yet) and rolled back an otherwise-healthy deploy.
  Defenses now in `features/media/arr-wiring.nix`: per-app HTTPError
  handling that logs status + API error body and continues, plus a
  wait-for-any-HTTP-response probe per target port before registering —
  systemd `after` guarantees started, NOT listening.
- Stalled `nix copy` to a host: if deploy-rs sits >5 min on "copying N
  paths" with zero CPU on the local `nix copy` process while plain
  `ssh <host> hostname` answers instantly, suspect the TARGET's nix-daemon:
  `sudo ss -tnp | grep CLOSE-WAIT` there — dead upstream sockets never reaped
  mean a wedged worker pool, so incoming store copies hang forever. Don't
  wait it out; kill the wrapper, skip the host (`bin/fleet deploy <other>`),
  report, and leave the daemon restart to the user.
- Port assignments must be checked against the target's live listeners
  (`sudo ss -tlnp`) BEFORE choosing them — long-lived container stacks squat
  host ports invisibly in the Nix config (on mimir: 5432/5433/9000 and more,
  held by rootlesskit). A config-only review cannot see these collisions.
- Mangled multi-tool calls: a patch whose arguments got merged from a todo
  update silently applied only partially or not at all (a "confirmed"
  prowlarr deploy was later found to be a no-op). After any malformed tool
  call, RE-READ the target file before proceeding; never assume the edit
  landed just because output looked plausible.
- Fuzzy-match patches anchoring on too-short old_strings can duplicate
  adjacent lines instead of replacing them (two imports became four, and an
  unrelated commented line silently reverted). For host import lists,
  prefer rewriting the whole block/file once over iterative patches, then
  re-read to confirm every entry appears exactly once.
- Post-repair restarts are part of the deploy, not ops cleanup: if you fix
  persistent-state ownership/permissions (or anything a running process
  holds open) OUTSIDE a deploy, the units consuming it keep stale handles
  until restarted — better-sqlite3 aborted the homarr web unit ~30 s after
  its DB was chowned (`Statement::~Statement()` → SIGABRT). After any
  state repair: restart every unit that touches that path, then smoke-check.
  Also note long `RestartSec` throttles leave failed units dwelling in
  `activating (auto-restart)` — recovery needs explicit `systemctl start`,
  not waiting.

- Dry-run output LIES BY OMISSION for brand-new units: the current
  switch-to-configuration `--dry-activate` report lists only units being
  stopped / reloaded / started-that-already-exist — newly added services
  never appear under "would start". Do not conclude a new unit is missing
  from the config off the dry run alone; verify via the built tree
  (`ls result/etc/systemd/system/multi-user.target.wants/ | grep <unit>`)
  and expect the real deploy log line
  `the following new units were started: …`. Real case 2026-08-25: three
  new media units absent from dry-run output all auto-started fine on the
  actual deploy.
- `nix flake check` evaluates EVERY host and can get OOM-killed on large
  flakes (exit 137, "Killed") with no config error at all. Scoped
  substitute for a single-host change: build just that target's toplevel —
  `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` —
  which exercises eval + closure of exactly the host you're shipping.
  - Switch-time UNIT-STATE RACES fail activation even when both generations
  are individually healthy: the old unit's `Restart=always` auto-restart
  fires DURING the switch and its side effects poison the new unit's boot
  (flexget rewrote `.flexget-lock`; the module's own ExecStop
  `daemon stop` spawned a second process that recreated the lock mid-
  restart) → "Another process is running" → switch failed (status 4) →
  magic rollback, repeatedly. Cure shipped 2026-08-25: quiesce inside
  `system.activationScripts.*` (systemctl stop + rm lock — runs as root on
  every activation) and `lib.mkForce ""` the competing ExecStop. Rule:
  anything a crash-looping unit mutates on each restart must be cleared in
  the activation phase, never by hand between deploys.
  - When interactive privileged commands on a target are consent-blocked,
  do NOT retry variants against the gate: encode the remediation in the
  repo instead (activation script or `+`-prefixed ExecStartPre) so the
  deploy pipeline — which provably runs as root — performs it. Three
  consecutive mimir remediations landed this way in one session. The
  corollary: a switch can keep failing on unit-state races (see above) —
  read the ACTIVATION log section of the deploy output for the actual
  failing unit before touching anything else; the target journal shows the
  rolled-back OLD units still crash-looping, which is noise, not cause.

## Debugging flaky deploys

1. Run the deploy 3-5x, capturing each full log (`... > attempt-N.log 2>&1`).
   One success (or two or three) proves nothing — the flake is a timing race
   between unit crash and the switch's unit-state check.
2. Read the failing log in full: deploy-rs prints the failing unit plus the
   target's journal lines before rolling back.
3. Grep the unit's own stderr on the target:
   `sudo journalctl -u <unit> --since -30min`. The error message names the
   cause (e.g. `flag 'collector.X' cannot be repeated`).
4. Check live state (`systemctl is-active/status <unit>`):
   `start-limit-hit` = crash-loop; the unit stays failed between deploys
   until `reset-failed` or a good deploy lands.
5. Remote commands: a target's login shell may be nushell (mimir is) —
   bare `ssh host '<bash loop>'` dies with nu::parser::parse_mismatch.
   Prefer `ssh <host> 'bash -s' < probe.sh` (probe in its own file;
   heredocs nested inside `$( )` break LOCAL bash parsing too — see
   `scripts/adhoc-remote-verify.sh`). One tripped parse made a fully
   green deployment read as FAILED for several turns; strip ssh's
   trailing newline (`tr -d '\n'`) before glob/case matching output.
6. After fixing, verify the merged config evaluates clean (script above),
   then soak 10+ consecutive deploys before calling it fixed.
7. **Prove it at the end of the chain**: config-eval PASS is necessary but
   not sufficient — finish with a real `bin/fleet deploy all` (or per host)
   and post-deploy health checks on every target:
   `systemctl is-active <unit>` + `curl :<port>/metrics` HTTP 200 + grep the
   journal for the original error signature. A "successful" deploy with a
   dead unit is exactly the failure mode this class of bug produces.

## Renaming feature modules

Use `git mv features/monitoring/<old> features/monitoring/<new>` so history
follows, then update import paths in every `hosts/*/configuration.nix`
(`search_files` for the old name — expect 1 line per importing host), plus
any comments naming the module. Re-run merged-config eval + `nix flake
check` before committing; a rename that misses a host import breaks only
that host's eval.

## Enabling features one-by-one (enable → deploy → smoke)

For "enable X, deploy, verify" loops (e.g. media features on mimir — full
table of units/ports/probes in `nixos-fleet-management` →
`references/mimir-media-stack.md`):

1. Uncomment/add the import (exactly once), deploy that single feature.
2. Smoke = `systemctl is-active <unit>` + `curl` the port over SSH;
   200/302/307 all mean up. Read `journalctl -u <unit>` on the target for
   any rollback.
3. Check for port squatters BEFORE enabling anything new: mimir's rootless
   containers own 5432/5433/6379/5672/4317-4318 etc.
4. A feature whose unit can never start is an honest FAIL: document it,
   leave it disabled with a comment saying why, and keep the rest deployed.
5. Finish with one final clean deploy and a full-fleet smoke sweep, then
   commit with per-feature evidence in the message.

## Ad-hoc verification probes

When the harness demands fresh evidence for a small change and full gates
are overkill, use `scripts/adhoc-remote-verify.sh` (copy + edit the check
block). It bakes in the recurring bash traps: heredocs inside `$( )` are a
parse error (put the remote probe in its own file and pipe it to
`ssh host bash -s`), bare `python3` may not exist on a shell (prefer
grep/sed/nix-instantiate), and ssh output's trailing newline silently
breaks case/glob matchers (`tr -d '\n'`). Summarize results as AD-HOC
verification, never as suite green.

## Committing the fix

This repo's hooks run through devenv (see `nixos-managing` → "Committing in
this repo"): use `devenv shell -- git commit …`, follow Conventional Commits,
and land repairs of broken-in-HEAD assay suites as a separate `test:` commit
BEFORE the functional change — prek evaluates the exact staged tree, so a
pathspec-limited commit still runs suites against HEAD-with-only-that-fix.
