# Colocated suite: atuin as the local-only history owner.
#
# The module is option-gated on one knob that mutates real user state, so the suite exercises
# both states. The facts worth pinning are the ones a later wave can break without noticing:
# the activation-script name (a generic one collides with alacritty's), that the config this
# host ships never reaches the network, that the write-ahead-log timer exists and does not need
# a graphical session, and that the fish import stays opt-in and stamped.
#
# Claims read the module evaluated against the real NixOS option tree. The checkpoint script
# reaches config only as a store path inside ExecStart, so its text is read back out of the
# .drv the evaluator wrote for it — the generated script is the artifact, not default.nix.
# config.toml is a TOML artifact and is parsed, not grepped.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  settings = {
    username = "alice";
    userdir = "/home/alice";
  };
  eval = atuin:
    nixos.eval {
      modules = [./default.nix {cli.atuin = atuin;}];
      inherit settings;
    };

  base = eval {};
  importing = eval {importFishHistory = true;};

  # The `attr` of the derivation named `name` that `str` refers to, read from its .drv
  # (structured-attrs derivations keep everything in one __json entry).
  unescape = builtins.replaceStrings ["\\\\" "\\\"" "\\n" "\\r" "\\t"] ["\\" "\"" "\n" "\r" "\t"];
  envOf = aterm: name:
    unescape (builtins.head (lib.splitString "\")])" (builtins.head (lib.splitString "\"),(\""
            (builtins.elemAt (lib.splitString "(\"${name}\",\"" aterm) 1)))));
  drvAttr = name: str: attr: let
    drvPath =
      builtins.head (builtins.filter (lib.hasSuffix "-${name}.drv")
        (builtins.attrNames (builtins.getContext str)));
    # The values are compared as text; the store references they carry are not needed.
    aterm = builtins.unsafeDiscardStringContext (builtins.readFile drvPath);
  in
    if lib.hasInfix "(\"__json\",\"" aterm
    then (builtins.fromJSON (envOf aterm "__json")).${attr}
    else envOf aterm attr;

  configToml = builtins.fromTOML (builtins.readFile ./config.toml);

  activation = base.system.activationScripts.linkAtuinConfig.text;
  importActivation = importing.system.activationScripts.importAtuinFishHistory;
  service = base.systemd.user.services.shell-history-checkpoint;
  timer = base.systemd.user.timers.shell-history-checkpoint;
  checkpointScript = drvAttr "shell-history-checkpoint" service.serviceConfig.ExecStart "text";
  # Shell comments in the script explain the code; claims are about the commands.
  checkpointCode =
    lib.concatStringsSep "\n"
    (builtins.filter (l: !(lib.hasPrefix "#" (lib.trim l))) (lib.splitString "\n" checkpointScript));

  has = haystack: needle: lib.hasInfix needle haystack;
in
  assay.suite "atuin" {
    installsAtuin = assay.eq (nixos.hasPackage base "atuin") true;

    # ---------------------------------------------------------------------------
    # The activation script and its name
    # ---------------------------------------------------------------------------
    #
    # features/window-manager/alacritty already claims the generic `linkFile`, and two
    # features writing one activation-script name is an evaluation conflict, not a merge.
    activationScriptName = assay.eq (base.system.activationScripts ? linkAtuinConfig) true;
    doesNotClaimGenericLinkFile = assay.eq (base.system.activationScripts ? linkFile) false;

    # The link target is the generated store copy of config.toml.
    linksConfigIntoPlace =
      assay.eq (builtins.match ".*ln -sfn /nix/store/[a-z0-9]+-atuin-config\\.toml /home/alice/\\.config/atuin/config\\.toml.*" activation != null) true;
    # Activation runs as root. Without this the user owns none of their own history config.
    chownsToUser = assay.eq (has activation "chown -R alice:users /home/alice/.config/atuin") true;
    # Atuin writes its own default config.toml on first run; that file, or a hand-edit of it,
    # gets moved aside rather than clobbered.
    keepsAPreExistingRealFile =
      assay.eq (has activation "mv /home/alice/.config/atuin/config.toml /home/alice/.config/atuin/config.toml.backup") true;

    # ---------------------------------------------------------------------------
    # Local only
    # ---------------------------------------------------------------------------
    #
    # Both of these default to reaching the network in atuin 18.24, which is why the config
    # states them rather than relying on a default that is not the one we want.
    syncIsOff = assay.eq configToml.auto_sync false;
    updateCheckIsOff = assay.eq configToml.update_check false;
    # No server is named at all: with sync off and no session key there is nothing to point
    # at one, and an address in the file would record an intent this host does not have.
    namesNoSyncServer = assay.eq (configToml ? sync_address) false;
    # A daemon would be a second writer to the same SQLite file, and has nothing to do with
    # sync switched off.
    daemonIsOff = assay.eq configToml.daemon.enabled false;
    secretsAreFiltered = assay.eq configToml.secrets_filter true;

    # ---------------------------------------------------------------------------
    # The write-ahead log
    # ---------------------------------------------------------------------------
    #
    # PASSIVE (SQLite's own auto-checkpoint) recycles the log in place and leaves it at its
    # high-water mark, which is how 1.6 MB of Nushell history came to carry a 4.2 MB -wal.
    # TRUNCATE is the mode that gives the space back.
    checkpointTruncates = assay.eq (has checkpointCode "PRAGMA wal_checkpoint(TRUNCATE);") true;
    checkpointTimerExists = assay.eq (base.systemd.user.timers ? shell-history-checkpoint) true;
    checkpointServiceIsOneshot = assay.eq service.serviceConfig.Type "oneshot";
    # Both databases, as the script's arguments.
    checkpointsBothHistories = assay.eq (builtins.tail (lib.splitString " " service.serviceConfig.ExecStart)) [
      "/home/alice/.config/nushell/history.sqlite3"
      "/home/alice/.local/share/atuin/history.db"
    ];
    timerIsWanted = assay.eq timer.wantedBy ["timers.target"];
    timerIsDaily = assay.eq timer.timerConfig.OnCalendar "daily";
    # A host that is off at midnight still gets its checkpoint.
    timerCatchesUp = assay.eq timer.timerConfig.Persistent true;
    # features/cli/nixos-update-notifier wants and follows graphical-session.target because it
    # draws a notification. This unit only touches files, and huginn / mimir / muninn / the
    # installer never start a graphical session — which is where an unattended log grows
    # longest. So the unit declares no session ordering at all.
    needsNoGraphicalSession = assay.eq [service.wants service.after] [[] []];
    # sqlite3 creates the file it is pointed at; a maintenance timer must not be how a host
    # acquires an empty history database.
    skipsAbsentDatabases = assay.eq (has checkpointCode ''[ -f "$db" ] || continue'') true;

    # ---------------------------------------------------------------------------
    # The orphaned fish history
    # ---------------------------------------------------------------------------
    #
    # `atuin import fish` writes to the live database, so it is the one part of this feature
    # that is off until asked for, and stamped so that asking twice is not two imports.
    importIsOptIn = assay.eq base.cli.atuin.importFishHistory false;
    importEmitsNothingWhenOff =
      assay.eq (base.system.activationScripts ? importAtuinFishHistory) false;
    # The import resolves db_path out of config.toml, so the link must already be in place.
    importRunsAfterTheConfigLink = assay.eq importActivation.deps ["linkAtuinConfig"];
    importUsesAtuinsOwnMechanism =
      assay.eq (builtins.match ".*/nix/store/[a-z0-9]+-atuin-[^/]+/bin/atuin import fish.*" importActivation.text != null) true;
    # Re-running would duplicate every row rather than merge, so the stamp is a guard checked
    # before anything runs, and not just a record.
    importIsGuardedByTheStamp =
      assay.eq (has importActivation.text "if [ -f /home/alice/.local/share/fish/fish_history ] && [ ! -e /home/alice/.local/share/atuin/.fish-history-imported ]; then") true;
    importWritesTheStamp =
      assay.eq (has importActivation.text "> /home/alice/.local/share/atuin/.fish-history-imported") true;
    # A login shell here would start nushell; the import runs the binary directly, as the user
    # who owns the database.
    importRunsAsTheUser = assay.eq (builtins.match ".*/bin/runuser -u alice --.*" importActivation.text != null) true;
    # The importer resolves both the fish history file and atuin's own config against the XDG
    # variables, and the environment `nixos-rebuild` ran in is not the user's session.
    importDoesNotInheritXdgPaths =
      assay.eq
      (map (has importActivation.text) [
        "HOME=/home/alice"
        "XDG_CONFIG_HOME=/home/alice/.config"
        "XDG_DATA_HOME=/home/alice/.local/share"
      ])
      [true true true];

    # vfiles (GH-188): the config link, owned by the user; the import still runs after it.
    vfilesLinksTheConfig = let
      f = base.vfiles.files."/home/alice/.config/atuin/config.toml";
    in
      assay.eq [f.mode f.user (lib.hasSuffix "-atuin-config.toml" "${f.source}")] ["link" "alice" true];
    importFollowsTheLegacyLinkWhileVfilesIsOff = assay.eq importing.system.activationScripts.importAtuinFishHistory.deps ["linkAtuinConfig"];
  }
