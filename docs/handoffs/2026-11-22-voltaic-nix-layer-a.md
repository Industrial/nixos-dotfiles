# Handoff: Voltaic Nix Layer A (Industrial/nixos-dotfiles)

You are continuing a multi-day programme in the user's NixOS dotfiles repository at
`/home/tom/.dotfiles` (GitHub `Industrial/nixos-dotfiles`, branch `main`). Read this whole file
before acting. Then read `AGENTS.md`, the memory index at
`~/.claude/projects/-home-tom--dotfiles/memory/MEMORY.md` (every linked file is a hard-won rule), the
mission plan `.maestro/missions/voltaic-nix-layer-a.plan.md` (its execution log is the history) and
the agent brief `.tmp/vnla/brief-common.md` (19 rules every sub-agent must follow).

## 1. Goal

Replace pieces of NixOS and C++ Nix with tools written in **Voltaic** (a Haskell-shaped language
that compiles to Rust; `https://github.com/Industrial/voltaic`) plus **id_effect 0.13.0** (effects,
capabilities, Schedules, fibers: no hand-rolled loops, threads, retries or timers). Each tool lives
in `rust/tools/<name>` as a standalone crate and **takes over the default path**: the system uses
it automatically, the old tool is removed or demoted, and one option rolls back. Additions with
nothing to replace are labelled "additions".

## 2. The fleet

- **drakkar**: this machine, the user's workstation, the only builder and the binary cache. Deploys
  through **vdeploy** (deploy mode, health-checked, automatic rollback); comin is retired there.
- **mimir**: online; still deployed by comin. Runs vdeploy in **observe mode** (plans, never switches).
- **huginn, muninn**: **permanently offline** (no WiFi, router ports full). Never plan around them.
- Login shell everywhere, including the user's own terminal, is **nushell**. Give the user commands
  as `bash -c '…'`; reach hosts with `ssh -o BatchMode=yes tom@host bash -s <<'EOF' … EOF`.

## 3. What is live (all on drakkar unless noted)

| Tool | Replaced / role | Issue |
|---|---|---|
| vgc, vopt (peer dotfiles-23's) | nix-collect-garbage / auto-optimise-store (drakkar + mimir) | #142 #167 |
| nix-store-core | shared store library (storepath, nar, narinfo, signing, drv, db, worker protocol, generations) | #152 |
| vcache | binary cache (addition); mimir substitutes from it | #147 |
| vfetch serve | first substituter: every `nix build` downloads through it | #155 |
| vbuild | Nix `build-hook` (replaced build-remote) | #156 |
| vdaemon-proxy | owns the daemon socket; **answers IsValidPath + QueryPathInfo natively** | #157 #183 |
| vdiff / vmon / vwhy | nvd / nix-output-monitor / nix-tree | #153 #181 #182 |
| vfiles | 16 dotfile activationScripts | #188 |
| vgen | generation retention + boot entries (before vgc) | #190 |
| vbump | scheduled per-input flake updates, one PR each | #189 |
| vverify, vhealth | store verification, service health probes (additions) | #158 #180 |
| vdeploy | deploy agent; replaced comin on drakkar; observe mode on mimir | #159 #160 #221 |
| userborn (upstream) | update-users-groups.pl | #187 |
| lanzaboote (upstream) | systemd-boot installer, **not enabled yet** (#208) | #184 |

Board: `https://github.com/users/Industrial/projects/3` (Status: Ready / In Progress / In Review / Deployed).
Tracking issue: #150.

## 4. In flight at handoff time (check each first)

1. **#233** Voltaic `=0.2.1` → `=0.3.0` for all 18 crates. User-approved; auto-merge armed after the
   `voltaicPinned` assay claims were fixed. Peer review: the generated Rust is byte-identical to 0.2.1.
   When it merges, the memory file `voltaic-build-recipe.md` must be updated from "pin =0.2.1" to "=0.3.0".
2. **#144** oomkiller daemon on id_effect (peer PR, owner gone). A sub-agent was rebasing and landing it
   (worktree `.tmp/worktrees/gh-140`).
3. **spike/gh-185-etc-overlay**: a sub-agent was turning it into a test-only PR
   (`test(etc-overlay): measurement nixosTests…`, Refs #185).
4. **#160** vdeploy take-over: deploys are healthy since the vhealth-user fix (#230 + a one-off root
   rebuild by the user). The remaining AC: time ≥5 merges merge→switched against comin's 4-minute drakkar
   median (`.tmp/vnla/gh-160/scripts/measure.sh`); a stale "bad" ledger entry from the old daemon must not
   block a future rollback (fix PR #231 merged; confirm).

## 5. Waiting on the user (don't do these yourself)

- **#208 lanzaboote on drakkar:** `bash -c 'sudo nix run nixpkgs#sbctl -- create-keys'`, back up
  `/var/lib/sbctl` off the machine, then merge #208; after the switch `sudo sbctl verify` and
  `sudo rm -f /boot/loader/entries/nixos-*.conf`; reboot at the machine; verify with `bootctl status`.
  Our install hook (#212) makes lanzaboote use comin's/vdeploy's profiles; the boot default was verified
  correct (#209).
- **vbump GitHub App** (#189): the user creates the app and adds the secrets `VBUMP_APP_ID` and
  `VBUMP_APP_PRIVATE_KEY` (steps on #189/#228). Then run `gh workflow run update-flake-lock.yml`
  and verify: token step ran, no warning, PRs from `<app>[bot]` start CI by themselves.
- **#185 /etc overlay:** whether to build `features.nixos.etc-overlay` (off by default) with a
  copy-the-state-before-first-boot step. The inventory is complete (user DBs, machine-id, ssh host keys,
  NetworkManager `Wired connection 1`, mullvad, wpa_supplicant, adjtime, opasswd).
- **mimir take-over** (vdeploy deploy mode): only after #160's 5 clean drakkar deploys, and mimir needs
  vhealth enabled first (deploy mode asserts it). mimir runs the STIG base-safe profile; #230's VM test
  already proves vhealth works under it.
- **Voltaic-as-Nix-language mission:** parked ("not yet"). The research report proposed 4 spikes
  (S1 a `.drv` writer golden-tested against our 56 fixtures, S2 one package, S3 one NixOS feature emitting
  a module, S4 edit→drv latency + snix). Don't start it without the user.

## 6. Open follow-up issues (no owner yet)

#225 vdeploy (comin tombstone, `evalSelection` one-option limit, EFI reboot test) · #224 vdaemon-proxy
(journal rate limit, 4 more native ops, SIGTERM finalizers) · #221 vdeploy (Fetcher→vfetch, counters reset
on restart, clone size, comin-vs-vdeploy comparison on mimir) · #219 vfiles (transmission/arr/paperclip
scripts, stale docs) · #217 flaky `shell-budget` gate (re-run once when red on unrelated PRs) · #216 #215
vfetch speed (≥1.5× only with a cold narinfo cache today) · #207 #200 nixos-update-notifier (vdiff --json;
see per-input PRs) · #206 #205 userborn follow-ups · #179 helpers to promote into nix-store-core ·
#169 deepsec is a no-op (user chose to proceed without) · #165 Cargo.nix drift for workspace crates ·
#146 vcache vs harmonia benchmark (peer dotfiles-31) · #143 deploy-rs unpinned · #136 #140 oomkiller · #127.

## 7. How work is done here (non-negotiable)

- **Worktree + PR + auto-merge** for every change; never edit the main checkout (other sessions share it).
  Worktrees under `.tmp/worktrees/`. Never delete branches (a guard forbids it; the user runs
  `bash ~/.dotfiles/.tmp/vnla/delete-obsolete-branches.sh [--yes]`).
- **Ticket lifecycle** (`~/.claude/skills/ticket-lifecycle/SKILL.md`, dotfiles profile): card In Progress →
  PR (`Refs #n`, never Closes) → watch CI (`watch-pr.sh --interval 120`) → merge → **deploy check on the host
  with `bash bin/watch-fleet <sha> --probe '<script>'`** → card Deployed → close the issue with the evidence.
- **CI is the gate.** Every standalone crate gets clippy `-D warnings --locked`, tests, and a Nix package build
  with drakkar's pkgs. VM tests are NOT run on PRs: run them locally only through `.tmp/vnla/vmtest.sh`
  (machine-wide lock). Local cargo only through `.tmp/vnla/cargo.sh` (max 3 concurrent).
- **Take-overs need a live-switch nixosTest** (boot without, switch in, switch out) that imports the host's
  real hardening (STIG `allowed-users = ["@wheel"]`). Probe as a non-root user AND read the service's own
  metric. Two incidents came from skipping this: the daemon socket (#211) and vhealth's user (#230).
- **No root on hosts by agents** (no sudo, no `/run/wrappers/bin/sudo`, no `switch-to-configuration`).
  Hand the user an exact `bash -c '…'` command instead. The lean-ctx shell allowlist blocks sudo on purpose;
  never route around it.
- **Lockfiles:** a PR that changes nix-store-core's dependencies relocks every dependent
  (`cargo.sh <crate> metadata --offline`), or main goes red on `--locked`.
- **GitHub:** only the `Industrial` account (`GH_TOKEN=$(gh auth token --user Industrial)`, or
  `.tmp/vnla/gh-direct.sh`). `idcleartomwieland` is the user's **company** account: never use it.
  The API budget is shared by all agents: poll ≥120 s.
- **Speed targets are follow-up goals, not take-over gates** ("Keep our stuff"); correctness, safety and a
  tested rollback are gates.
- Peers: `dotfiles-23` (session name `dotfiles-30`) owns vgc/vopt/vgen-retention interplay; announce scopes
  with SendMessage before touching shared paths.

## 8. Useful files

`.tmp/vnla/` holds the working scripts: `brief-common.md`, `gh-direct.sh`, `stage.sh <n> <Status>`
(board moves), `vmtest.sh`, `cargo.sh`, `probe-*.sh` (per-tool deploy checks), `delete-obsolete-branches.sh`,
`sync-main-checkout.sh` (a safe main-checkout fast-forward with backup). It is gitignored and local to
drakkar; recreate the scripts from this description if they are missing.

## 9. Suggested next actions, in order

1. Confirm #233, #144 and the #185 test PR merged; run their deploy checks; update the Voltaic memory pin.
2. Finish #160's 5-merge timing; then propose mimir's take-over (enable vhealth on mimir first) for the
   user's go.
3. When the user has done the GitHub App steps, run vbump's end-to-end check (#189), then close it.
4. Pick up follow-ups by value: #224 (native ops), #221 (Fetcher→vfetch), #207/#200, #219, #179.
5. Keep the board accurate: every non-Deployed card has an owner (the user's standing rule).
