# Colocated suite: atuin as the local-only history owner.
#
# The module is option-gated on one knob that mutates real user state, so the suite exercises
# both states. The facts worth pinning are the ones a later wave can break without noticing:
# the activation-script name (a generic one collides with alacritty's), that the config this
# host ships never reaches the network, that the write-ahead-log timer exists and does not need
# a graphical session, and that the fish import stays opt-in and stamped.
let
  assay = import ./../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  src = builtins.readFile ./default.nix;
  configToml = builtins.readFile ./config.toml;

  eval = atuin:
    (nixpkgsLib.evalModules {
      modules = [
        ./default.nix
        {
          _module.args = {
            pkgs = import <nixpkgs> {};
            settings = {
              hostname = "h";
              username = "alice";
              userdir = "/home/alice";
            };
          };
          cli.atuin = atuin;
        }
        # Minimal stand-ins for the option trees this module writes.
        {
          options.environment.systemPackages = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.listOf nixpkgsLib.types.unspecified;
            default = [];
          };
          options.system.activationScripts = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
          options.systemd.user.services = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
          options.systemd.user.timers = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
        }
      ];
    })
    .config;

  base = eval {};
  importing = eval {importFishHistory = true;};

  activation = base.system.activationScripts.linkAtuinConfig.text;
  importActivation = importing.system.activationScripts.importAtuinFishHistory.text;
  service = base.systemd.user.services.shell-history-checkpoint;
  timer = base.systemd.user.timers.shell-history-checkpoint;

  has = haystack: needle: nixpkgsLib.hasInfix needle haystack;
in
  assay.suite "atuin" {
    systemPackages = assay.eq (map nixpkgsLib.getName base.environment.systemPackages) ["atuin"];

    # ---------------------------------------------------------------------------
    # The activation script and its name
    # ---------------------------------------------------------------------------
    #
    # features/window-manager/alacritty already claims the generic `linkFile`, and two
    # features writing one activation-script name is an evaluation conflict, not a merge.
    activationScriptName = assay.eq (base.system.activationScripts ? linkAtuinConfig) true;
    doesNotClaimGenericLinkFile = assay.eq (base.system.activationScripts ? linkFile) false;

    linksConfigIntoPlace = assay.eq (has activation "/home/alice/.config/atuin/config.toml") true;
    linksRatherThanCopies = assay.eq (has activation "ln -sfn") true;
    # Activation runs as root. Without this the user owns none of their own history config.
    chownsToUser = assay.eq (has activation "chown -R alice:users") true;
    # Atuin writes its own default config.toml on first run; that file, or a hand-edit of it,
    # gets moved aside rather than clobbered.
    keepsAPreExistingRealFile = assay.eq (has activation "config.toml.backup") true;

    # ---------------------------------------------------------------------------
    # Local only
    # ---------------------------------------------------------------------------
    #
    # Both of these default to reaching the network in atuin 18.24, which is why the config
    # states them rather than relying on a default that is not the one we want.
    syncIsOff = assay.eq (has configToml "auto_sync = false") true;
    updateCheckIsOff = assay.eq (has configToml "update_check = false") true;
    # No server is named at all: with sync off and no session key there is nothing to point
    # at one, and an address in the file would record an intent this host does not have.
    namesNoSyncServer = assay.eq (has configToml "sync_address =") false;
    namesNoSyncHost = assay.eq (has configToml "atuin.sh") false;
    # A daemon would be a second writer to the same SQLite file, and has nothing to do with
    # sync switched off.
    daemonIsOff = assay.eq (has configToml "enabled = false") true;
    secretsAreFiltered = assay.eq (has configToml "secrets_filter = true") true;

    # ---------------------------------------------------------------------------
    # The write-ahead log
    # ---------------------------------------------------------------------------
    #
    # PASSIVE (SQLite's own auto-checkpoint) recycles the log in place and leaves it at its
    # high-water mark, which is how 1.6 MB of Nushell history came to carry a 4.2 MB -wal.
    # TRUNCATE is the mode that gives the space back.
    checkpointTruncates = assay.eq (has src "wal_checkpoint(TRUNCATE)") true;
    checkpointTimerExists = assay.eq (base.systemd.user.timers ? shell-history-checkpoint) true;
    checkpointServiceIsOneshot = assay.eq service.serviceConfig.Type "oneshot";
    checkpointsNushellHistory =
      assay.eq (has service.serviceConfig.ExecStart "/home/alice/.config/nushell/history.sqlite3") true;
    # Atuin's own database is the same kind of file with the same habit.
    checkpointsAtuinHistory =
      assay.eq (has service.serviceConfig.ExecStart "/home/alice/.local/share/atuin/history.db") true;
    timerIsWanted = assay.eq timer.wantedBy ["timers.target"];
    timerIsDaily = assay.eq timer.timerConfig.OnCalendar "daily";
    # A host that is off at midnight still gets its checkpoint.
    timerCatchesUp = assay.eq timer.timerConfig.Persistent true;
    # features/cli/nixos-update-notifier wants and follows graphical-session.target because it
    # draws a notification. This unit only touches files, and huginn / mimir / muninn / the
    # installer never start a graphical session — which is where an unattended log grows
    # longest. So the unit declares no session ordering at all.
    needsNoGraphicalSession = assay.eq [(service ? wants) (service ? after)] [false false];
    # sqlite3 creates the file it is pointed at; a maintenance timer must not be how a host
    # acquires an empty history database.
    skipsAbsentDatabases = assay.eq (has src ''[ -f "$db" ] || continue'') true;

    # ---------------------------------------------------------------------------
    # The orphaned fish history
    # ---------------------------------------------------------------------------
    #
    # `atuin import fish` writes to the live database, so it is the one part of this feature
    # that is off until asked for, and stamped so that asking twice is not two imports.
    importIsOptIn = assay.eq base.cli.atuin.importFishHistory false;
    importEmitsNothingWhenOff =
      assay.eq (base.system.activationScripts ? importAtuinFishHistory) false;
    importUsesAtuinsOwnMechanism = assay.eq (has importActivation "atuin import fish") true;
    importReadsTheOrphanedFile =
      assay.eq (has importActivation "/home/alice/.local/share/fish/fish_history") true;
    importIsStamped =
      assay.eq (has importActivation "/home/alice/.local/share/atuin/.fish-history-imported") true;
    # Re-running would duplicate every row rather than merge, so the stamp is a guard and not
    # just a record.
    importChecksTheStampFirst = assay.eq (has importActivation "[ ! -e ") true;
    # A login shell here would start nushell; the import runs the binary directly, as the user
    # who owns the database.
    importRunsAsTheUser = assay.eq (has importActivation "runuser -u alice --") true;
    # The importer resolves both the fish history file and atuin's own config against the XDG
    # variables, and the environment `nixos-rebuild` ran in is not the user's session.
    importDoesNotInheritXdgPaths =
      assay.eq
      (map (has importActivation) [
        "HOME=/home/alice"
        "XDG_CONFIG_HOME=/home/alice/.config"
        "XDG_DATA_HOME=/home/alice/.local/share"
      ])
      [true true true];
  }
