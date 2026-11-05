# Atuin is a SQLite-backed shell history with search. It's a replacement for the shell's own
# history file.
#
# The shell integration is not here: features/cli/shell-init generates `40-atuin.nu` from the
# installed binary's own `atuin init nu` into `$nu.data-dir/vendor/autoload`, and that is what
# registers the `atuin` and `atuin_up_arrow` keybindings. What is left for this feature is the
# three things that are not keybindings — the local-only config, the one-shot rescue of the fish
# history the Nushell migration stranded, and the write-ahead logs the history databases grow.
{
  config,
  lib,
  pkgs,
  settings,
  ...
}:
with lib; let
  cfg = config.cli.atuin;

  configDir = "${settings.userdir}/.config/atuin";
  dataDir = "${settings.userdir}/.local/share/atuin";

  configFile = pkgs.writeTextFile {
    name = "atuin-config.toml";
    text = builtins.readFile ./config.toml;
  };

  # ---------------------------------------------------------------------------
  # The orphaned fish history
  # ---------------------------------------------------------------------------
  #
  # Switching the login shell to Nushell left ~/.local/share/fish/fish_history behind: 3.2 MB
  # and 17246 `- cmd:` entries that no shell reads any more. `atuin import fish` is the only
  # mechanism that reads that format, and it writes straight into the live history database —
  # so it is opt-in (the option below defaults to false) *and* stamped, because a second import
  # would duplicate all 17246 rows rather than merge them.
  fishHistory = "${settings.userdir}/.local/share/fish/fish_history";
  importStamp = "${dataDir}/.fish-history-imported";

  # ---------------------------------------------------------------------------
  # Write-ahead logs
  # ---------------------------------------------------------------------------
  #
  # Nushell's `history.sqlite3` is 1.6 MB carrying a 4.2 MB -wal, because `sync_on_enter` plus
  # `isolation` in its config.nu writes on every command and nothing ever checkpoints. SQLite's
  # own auto-checkpoint runs in PASSIVE mode, which recycles the log in place; only TRUNCATE
  # gives the space back to the filesystem. Atuin's own `history.db` is the same kind of file
  # with the same habit, so it gets the same treatment from the same unit.
  historyDatabases = [
    "${settings.userdir}/.config/nushell/history.sqlite3"
    "${dataDir}/history.db"
  ];

  checkpoint = pkgs.writeShellScript "shell-history-checkpoint" ''
    set -u
    status=0
    for db in "$@"; do
      # sqlite3 creates the file it is pointed at. A host where the shell has never run must
      # not end up with an empty history database courtesy of a maintenance timer.
      [ -f "$db" ] || continue

      # TRUNCATE needs a moment with no other reader. A busy database is "try again
      # tomorrow", not a failed unit: the log stays where it was and no history is lost.
      ${pkgs.sqlite}/bin/sqlite3 "$db" \
        'PRAGMA busy_timeout = 5000; PRAGMA wal_checkpoint(TRUNCATE);' >/dev/null \
        || status=1
    done
    exit "$status"
  '';
in {
  options.cli.atuin = {
    importFishHistory = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Import `~/.local/share/fish/fish_history` into atuin's database once, during
        activation, guarded by a stamp file at `${importStamp}`.

        Off by default because it mutates real user state: it is the only part of this
        feature that writes to the history database rather than to configuration. Turn it
        on for one rebuild on a host that still has a fish history worth rescuing. The
        stamp means leaving it on afterwards is a no-op, and removing the stamp is how you
        ask for the import again.
      '';
    };
  };

  config = mkMerge [
    {
      environment.systemPackages = with pkgs; [
        atuin
      ];

      # Named linkAtuinConfig rather than the generic linkFile that
      # features/window-manager/alacritty/default.nix already claims: two features writing
      # one activation-script name is an evaluation conflict, not a merge.
      system.activationScripts.linkAtuinConfig = {
        text = ''
          mkdir -p ${configDir}
          # Atuin writes a default config.toml on its first run if none exists. If that
          # happened before this feature landed — or if the file was hand-edited — keep it
          # rather than clobber it, the same way features/cli/nushell does.
          if [ -f ${configDir}/config.toml ] && [ ! -L ${configDir}/config.toml ]; then
            mv ${configDir}/config.toml ${configDir}/config.toml.backup
          fi
          ln -sfn ${configFile} ${configDir}/config.toml
          chown -R ${settings.username}:users ${configDir}
        '';
      };

      # A user timer, because the databases live under the user's home and are owned by the
      # user. Unlike features/cli/nixos-update-notifier this one deliberately does *not* want
      # or follow graphical-session.target: huginn, mimir, muninn and the installer run a
      # shell and never a graphical session, and a headless host is exactly where an
      # unattended write-ahead log sits growing the longest.
      systemd.user.services.shell-history-checkpoint = {
        description = "Checkpoint and truncate the shell history SQLite write-ahead logs";

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${checkpoint} ${concatStringsSep " " historyDatabases}";
          # Maintenance has no deadline; interactive use does.
          Nice = 19;
          IOSchedulingClass = "idle";
        };
      };

      systemd.user.timers.shell-history-checkpoint = {
        description = "Daily checkpoint of the shell history SQLite write-ahead logs";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = "daily";
          # Hosts that are off at midnight still get their checkpoint.
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    }

    (mkIf cfg.importFishHistory {
      system.activationScripts.importAtuinFishHistory = {
        # The import resolves db_path out of config.toml, so the link goes in first.
        deps = ["linkAtuinConfig"];
        text = ''
          if [ -f ${fishHistory} ] && [ ! -e ${importStamp} ]; then
            install -d -o ${settings.username} -g users -m 0700 ${dataDir}
            echo "atuin: importing ${fishHistory} (one shot)"
            # atuin's fish importer resolves the history file under $XDG_DATA_HOME and its own
            # config under $XDG_CONFIG_HOME, so both are stated rather than inherited: whatever
            # environment `nixos-rebuild` ran in is not this user's session. A login shell
            # (runuser -l) would start nushell; this runs the binary directly.
            ${pkgs.util-linux}/bin/runuser -u ${settings.username} -- \
              ${pkgs.coreutils}/bin/env \
                HOME=${settings.userdir} \
                XDG_CONFIG_HOME=${settings.userdir}/.config \
                XDG_DATA_HOME=${settings.userdir}/.local/share \
                ${pkgs.atuin}/bin/atuin import fish
            # Written only on success: a failed import leaves no stamp, so the next
            # activation retries rather than silently skipping the rescue forever.
            date -u +%FT%TZ > ${importStamp}
            chown ${settings.username}:users ${importStamp}
          fi
        '';
      };
    })
  ];
}
