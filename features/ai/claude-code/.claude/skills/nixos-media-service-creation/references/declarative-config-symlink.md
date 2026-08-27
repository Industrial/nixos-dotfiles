# Declarative Config via Cursor-Pattern Symlink (all six arr apps)

prowlarr first 2026-08-23; replicated fleet-wide to
sonarr/radarr/lidarr/readarr 2026-08-24 (commit 2c44287e); whisparr
joined 2026-08-24 (commit 97c72cfb) as a NEW app — see step 0 below.

Goal: app config lives in the dotfiles repo and is symlinked into the
service's live data dir — the desktop-app pattern from
`features/programming/cursor/` (`.config/Cursor/…` sources +
`bin/link-files-nixos` doing `ln -sf` into `$HOME`), adapted for a native
system service whose UI *rewrites* its config file.

## Why the desktop pattern needed adaptation

| Cursor assumption | Prowlarr reality |
|---|---|
| Repo checkout on the machine | mimir had none → clone to `/data/dotfiles` |
| Target under `$HOME` | target is `/data/services/prowlarr/config.xml` |
| App treats config as read-only-ish | arr apps rewrite `config.xml` on every UI save |
| JSON config | arr server config is XML; JSON is only indexer exports |

## Implementation (features/media/prowlarr — reference for all five)

1. Source of truth: `features/media/prowlarr/config/config.xml`, seeded by
   copying the LIVE file (`/mnt/mimir/services/prowlarr/config.xml`, visible
   from drakkar via NFS mount `mimir:/data`). Verified its `<ApiKey>` equals
   `api-keys.nix`'s prowlarr value BEFORE committing — no new secret lands in
   git; canonical secret home stays api-keys.nix.
2. Module addition (`default.nix`): `system.activationScripts.prowlarrConfig`
   with exactly this safety order:
   - repo missing (`[ ! -f "$source" ]`) → warn to stderr, keep existing
     config, exit 0 (deploy must not break on a fresh host);
   - existing real file that differs (`-f && ! -L`, then `cmp -s`) → one-time
     `cp -a config.xml config.xml.bak.$(date +%Y%m%d%H%M%S)`;
   - `ln -sfn` (idempotent, never fails on re-link);
   - `chgrp data "$source"` + `chmod 0664` so the service (Group=data) can
     write UI changes back through the symlink into the repo working tree.
3. Suite: extended colocated assay 2→10 cases — activation attr declared,
   `/data/dotfiles/...config.xml` path embedded in script text, `ln -sfn`
   present, backup guard present, degradation message present, port in
   source, ApiKey parity vs imported api-keys.nix (values compared, never
   emitted). When the module gained `${pkgs.diffutils}/bin/cmp`, the suite's
   stub `pkgs` had to gain `diffutils` too and the `cmp -s` assertion regex
   was updated — see the production-defect note below.

## Replicating to another service (proven 2026-08-24 ×4, commit 2c44287e)

0. New app (no live config to snapshot): generate a fresh key
   `head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'`, add it to
   api-keys.nix, author the config.xml from a sibling app's (fix Port,
   SslPort, InstanceName; Branch per app channel), and extend EVERY
   wiring point in one commit: api-keys.assay expectedApps list (alphabetical),
   arr-wiring.nix apps.port + implementations map + CATEGORIES, arr-wiring
   assay's apps list. Reviving a stale module? Re-check its TODO against
   nixpkgs TODAY (`nix eval --raw nixpkgs#<name>.name` + build once) —
   whisparr's "not available on NixOS yet" header was months stale.
1. Snapshot the LIVE config: `ssh tom@mimir -- bash -c "'cat /data/services/<svc>/config.xml'"`
   (login shell is nushell — always wrap remote scripts in bash -c).
2. Verify the ApiKey equals the `api-keys.nix` value BEFORE writing the repo
   copy (parity is asserted by the assay; all four matched out of the box).
3. Per module, three insertion points — copy from
   `templates/arr-declarative-config.nix`: let-bindings
   (`dotfilesRepo`/`configSource` + comment), `system.activationScripts.<svc>Config`
   placed AFTER the systemd block, assay extension. Patch-anchor gotcha:
   `users = {` appears TWICE in these modules — anchor on the tmpfiles
   `"d ${directoryPath}/data ..."` rule instead.
4. Extend the colocated assay from prowlarr's suite (rename suite/attrs,
   port, api-keys attr; stub `pkgs` gains `diffutils = "/bin/cmp"`).
5. Gate order: `nix-instantiate --eval` each assay → `nix flake check` →
   `devenv shell -- assay run .` (was 629/629) → pathspec-limited commit → push.
   flake check catches undefined let-bindings; the assay run catches missing
   activation scripts (`attribute 'system' missing`) that flake check does not.
6. Sync the serving-host clone BEFORE deploying: `git -C /data/dotfiles pull --ff-only`.
   Activation reads the HOST clone, not the deployer's. If pull's autostash
   conflicts because a dirty host file was deleted upstream (homarr board.json
   case): the stash survives automatically (note its id for the user), then
   `git reset --hard` leaves the tree clean at origin/main.
7. Deploy + verify: `readlink -f /data/services/<svc>/config.xml` resolves
   inside `/data/dotfiles/features/media/<svc>/config/`; `systemctl is-active`;
   EXACTLY ONE `.bak.*` per service (the designed one-time backup — more than
   one means the inverted-cmp bug below); grep the deploy log for
   `command not found`.

## Superseding an app in the same slot (jellyseerr → seerr, 2026-08-24)

When two features serve the same role and the user names the survivor:
`grep -rn "<loser>" --include=*.nix .` first — if nothing outside its own
dir imports it, `git rm -r` is safe with zero other edits. Commit removal
and any new-feature work as SEPARATE commits (removal first) so revert
surfaces stay small.

## UI-edit sync-back / drift reconciliation (prowlarr, 2026-08-24)

UI changes land ONLY in the host clone's working tree. When the user asks to
check-and-commit them (they asked exactly this for prowlarr auth changes):

1. Read live through the symlink via ssh; fetch it to a local tmp file and
   `diff` against the repo copy (avoids nested-quoting traps).
2. Confirm the ONLY delta is the user's reported change (here:
   AuthenticationMethod None→Forms, AuthenticationRequired
   Enabled→DisabledForLocalAddresses). Also check mimir clone `git status`
   for unrelated dirty files before scoping the commit.
3. Apply to the deployer repo, commit, push, then fast-forward mimir's clone
   so both sides agree. Expect this flow regularly — see Tradeoff.

## Auth values: mechanism parity ≠ value parity

When replicating, services may legitimately diverge on settings like auth:
prowlarr ran Forms/DisabledForLocalAddresses while the other four still ran
None/Enabled. Ask the user whether to standardize; on timeout DEFAULT TO
snapshotting live values as-is — flipping AuthenticationMethod blindly can
lock the operator out of four UIs at once. Record the choice in the commit
message.

## Verification-consent lesson (2026-08-24)

The operator denied running a dedicated /tmp/hermes-verify-* verification
script (twice) and a compound remote smoke one-liner (once), while approving
plain individual read-only commands throughout (ssh cat/diff/readlink/
is-active, local diff/grep). Lesson for this environment: fold post-deploy
smoke checks into the deploy turn as simple approved-shaped commands rather
than introducing a new script artifact — each new script run is a fresh
approval gate. After a denial, never re-attempt that command shape ("do NOT
rephrase"); offer the remaining checks as a copy-pasteable snippet for the
user and report honestly which evidence was executed vs skipped.

## Fleet-wide rollout note (deploy all)

When the user asks for `bin/fleet deploy all`, one wedged target can stall
the whole wrapper mid-copy for 15+ minutes while other hosts wait behind it.
Pattern that worked: kill only the local background wrapper, deploy hosts
individually (`mimir`, `drakkar`), leave the stalled host out and hand the
daemon-restart decision to the user — see `nixos-deploy-rs` → "Stalled nix
copy" for the CLOSE-WAIT diagnosis.

## Tradeoff (accepted by user)

UI changes write through the symlink into mimir's clone working tree — they
survive reboots but are NOT committed; drift vs origin is visible via
`git status` on mimir. Treat declarative edits through git; treat UI edits
as local-only until synced back (see sync-back section above).

## Gotchas

- Remote host login shell is nushell: pipe scripts via `ssh host bash -s <<'EOF'`
  or wrap in `bash -c '"..."'` instead of `&&` chains.
- The `git reset --hard` on mimir's clone tripped a permission gate once —
  prefer letting the user sync, or use `git pull --ff-only`.
- Don't copy secrets into the repo blindly: diff-check key fields against
  their canonical declaration first (here KEYS-MATCH, else template them).
- Bash commit messages: a Nix interpolation like `${pkgs.diffutils}` inside
  a double-quoted `-m` string is parsed as parameter expansion ("bad
  substitution"). Use single quotes for messages containing `${...}`.
- Bash test spacing inside the generated script: `[ ! -L "$target" ]` —
  a missing space before `]` (`"$target"]`) sails through Nix eval and only
  explodes at activation time.
- Stale nixf/LSP diagnostics after rapid successive writes: lidarr's assay
  reported a parse ERROR that `nix-instantiate --eval` proved wrong. Trust
  the evaluator's exit code over editor diagnostics.

## Post-deploy defect found in production (cmp, 2026-08-23)

The first real activation exposed a bug the assay suite could not see:
`activate: line 208: cmp: command not found`. NixOS activation scripts run
with a minimal PATH lacking diffutils, so `if ! cmp -s target source`
failed, the leading `!` inverted that failure into "divergent", and a
spurious `config.xml.bak.<ts>` was created. Harmless but noisy. Fix:
interpolate the store path — ``${pkgs.diffutils}/bin/cmp -s ...`` — never
trust PATH inside activation scripts. Two ripple effects:

1. The suite's stub `pkgs` must gain `diffutils = "/x/cmp"` (any string) or
   eval fails with `attribute 'diffutils' missing`; update any assertion
   regex matching the script text too.
2. The deployed generation only carries the fix after a RE-deploy; the
   re-run is also the proof the idempotent path works (no new backup, no
   warnings).

Lesson: activation-script bugs surface only at real switch time on the
target — after shipping a new activation script, grep each deploy log for
`<script>: line N: <cmd>: command not found`; deploy-rs still reports
"Deployment confirmed." because activation exits 0.
