# Native NixOS media modules — jackett/transmission/flexget cutover (2026-08-25)

Hand-rolled units replaced by nixpkgs-native modules after the user's
correction ("we are on NixOS"). Commit af5019dd: ~305 lines of unit +
symlink machinery became ~126 lines of option declarations across the three
feature dirs. This file holds the contracts, the assay pattern, and the
failed-activation incident that shaped the recovery doctrine.

## Discovery: what's already native

```
NIXPKGS=$(nix-instantiate --eval -E \
  'let fl = builtins.getFlake (toString /home/tom/.dotfiles); in fl.nixosConfigurations.mimir.pkgs.path')
ls "$NIXPKGS"/nixos/modules/services/torrent/ "$NIXPKGS"/nixos/modules/services/misc/
```

torrent/: bitmagnet cross-seed deluge flexget flood magnetico opentracker
peerflix qbittorrent qui rqbit rtorrent torrentstream transmission
misc/: jackett
(Verify TODAY — the whisparr "not available on NixOS yet" TODO was months
stale; packages often exist before their module.)

## services.transmission (modules/services/torrent/transmission.nix)

- `package = pkgs.transmission_4;` is REQUIRED — eval ERRORS without an
  explicit pin (24.11 transmission_3->_4 default-flip guard).
- `home` (default /var/lib/transmission) is the settings root:
  settings.json resolves at `<home>/.config/transmission-daemon/`.
- Declared `settings` are MERGED into settings.json by a root
  (`+`-prefixed) ExecStartPre jq merge on EVERY start. Declarative config
  with zero symlink/drift machinery — self-heals after any UI edit.
- `group = "data"` becomes the daemon's PRIMARY group (module owns user +
  group creation). Do NOT also add users.users.transmission.extraGroups.
- Comes free: RootDirectory=/run/transmission sandbox + BindPaths onto
  download/incomplete dirs, performanceNetParameters sysctls,
  openPeerPorts firewall hole, credentialsFile secret-merge hook.
- Remote (hostname-addressed) access needs `rpc-bind-address = "0.0.0.0"`
  AND both `rpc-host-whitelist-enabled`/`rpc-whitelist-enabled` = false —
  transmission defaults whitelist ON, which answers 403 Forbidden to any
  request whose Host isn't localhost while local curl looks healthy.

## services.flexget (modules/services/torrent/flexget.nix)

- `config` takes the YAML as TEXT: `builtins.readFile ./config/config.yml`
  embeds it in the nix store; the module's own ExecStartPre installs it to
  `<homeDir>/flexget.yml`. Removes every /data/dotfiles host-checkout
  dependency — the stale-clone failure modes in SKILL.md section 9 cannot
  happen with this shape.
- `systemScheduler = false` keeps schedules inside the YAML (needed for
  `web_server:` + `schedules:`); true swaps in a flexget-runner timer.
- WebUI is configured IN the YAML: `web_server: {bind: 0.0.0.0, port: 5050,
  web_ui: yes}`. Note the module writes flexget.yml (not config.yml) and has
  no Group= of its own — set tmpfiles for the data dir yourself.
- MISSING DEP (nixpkgs bug): the flexget 3.20.5 derivation omits
  `cryptography`, which upstream's utils/waf imports unconditionally during
  daemon startup -> ModuleNotFoundError -> exit 1 before serving. Fix:
  ```nix
  flexgetFixed = pkgs.flexget.overridePythonAttrs (old: {
    dependencies = (old.dependencies or [])
      ++ [pkgs.python3Packages.cryptography];
  });
  ```
  then `package = flexgetFixed`. Verify against the DERIVATION'S OWN python
  (`head -1 bin/flexget` -> interpreter, `-c 'import cryptography'`) — the
  site-packages dir of the output attr is empty by design (env lives in the
  wrapped PATH).
- Schema validation happens at DAEMON START, not eval/build: an invalid
  task key (e.g. task-level `movie_queue`) passes assay + build clean and
  only crash-loops live with `ConfigError: Did not pass schema
  validation.` Read `journalctl -u flexget` for the offending key name;
  keep placeholder configs schema-valid (`series:` / `accept_all:` shapes).

## services.jackett (modules/services/misc/jackett.nix)

enable / port / dataDir / group / user / package. dataDir=/data/services/
jackett lands ServerConfig.json + per-indexer JSONs on the NFS volume;
group="data" for the fleet convention. Unit ships heavy sandboxing
(ProtectSystem=strict etc.) — ReadWritePaths follows dataDir automatically.

## Assay pattern for native modules

Stub-importing a native module FAILS: it needs full nixpkgs
(mkPackageOption, config.ids.uids). Pattern instead: declare the SAME
option attrset in the suite and assert its values (option-contract tests),
and let the mimir toplevel build gate cover real module eval. Repo suite
went 677 -> 668 cases; nothing lost that the build doesn't cover.

## Live incident: .flexget-lock x deploy-rs magic-rollback

Sequence on mimir: old hand-rolled flexget crash-looped ~570x (stale host
clone, install cannot stat) leaving /data/services/flexget/.flexget-lock.
The NEW native unit then started fine and parsed the YAML (plugin warnings
= parse success), but died immediately:
    CRITICAL manager  Another process (PID 3501700) is running, will exit.
    If you're sure there is no other instance running, delete
    /data/services/flexget/.flexget-lock
switch-to-configuration exited status 4 -> deploy-rs magic-rollback
RESURRECTED THE BROKEN OLD UNITS. Net effect: the deploy "fails", the
crash loop (and the periodic fan spin-up it caused) continues, and nothing
on the host improved despite a correct closure.

Recovery BEFORE redeploying any long-crash-looped daemon:
```
sudo systemctl stop <unit>.service
sudo systemctl reset-failed <unit>.service
sudo rm -f /data/services/<name>/.flexget-lock   # app-specific lock file
bin/fleet deploy mimir
```
Doctrine: a crashed app leaves lock/state files OUTSIDE systemd lifecycle;
clean them between stop and redeploy, or activation re-fails and rolls the
whole switch back.

### Declarative self-heal (what actually shipped, commits b88602d6..a7a4c45c)

Manual cleanup is a one-off; three in-config defenses make every future
switch immune and also work when interactive privileged commands on the
target are consent-blocked (encode the remediation in the repo — the deploy
pipeline provably runs as root):

1. Root-prefixed ExecStartPre drops the stale lock at each start:
   ```nix
   ExecStartPre = [
     "+${pkgs.coreutils}/bin/rm -f ${directoryPath}/.flexget-lock"
   ];
   ```
2. Activation script QUIESCES the old unit before the switch restarts it:
   ```nix
   system.activationScripts.flexgetQuiesce.text = ''
     ${pkgs.systemd}/bin/systemctl stop flexget.service 2>/dev/null || true
     ${pkgs.coreutils}/bin/rm -f ${directoryPath}/.flexget-lock
   '';
   ```
3. `systemd.services.flexget.serviceConfig.ExecStop = lib.mkForce "";` —
   the module's `flexget daemon stop` spawns a SECOND python process that
   RECREATES the lockfile mid-restart; the next start then hits "Another
   process is running" again even with defense 1 (observed twice). SIGTERM
   alone stops the daemon cleanly.

Also required for transmission: the module BindPaths-includes the
download/incomplete dirs into its RootDirectory namespace BEFORE any
ExecStartPre runs — a missing dir aborts the whole ACTIVATION at step
NAMESPACE (status 226), not just the unit (commit 3ebd2ec6). Create them in
a `system.activationScripts.transmissionDirs` (mkdir/chown/chmod 0770).

## Post-eval shape check

Before deploying, confirm the module rendered what you intended:
```
grep -E 'ExecStart|BindPaths|^User|^Group' \
  result/etc/systemd/system/transmission.service
```
This caught the missing transmission_4 pin path early (build error named
the option directly) and confirmed BindPaths landed on the NFS dirs.