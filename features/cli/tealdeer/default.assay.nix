# Colocated suite: tealdeer as the offline help owner.
#
# The facts worth pinning here are the ones a later wave can break without noticing: that no
# part of this feature reaches the network during activation, that the seed is pinned to a
# release rather than to `latest`, that it lands in the one directory tealdeer actually reads,
# that it never overwrites a cache the user has since refreshed, and that the refresh unit
# needs no graphical session because most of this fleet never starts one.
#
# The module is evaluated against the real NixOS option tree. The seed and the refresh script
# reach config only as store paths inside the activation script and ExecStart, so their build
# attributes (the unpack command, the archive's URL and hash, the script text) are read back
# out of the .drv files the evaluator wrote. config.toml is a TOML artifact and is parsed.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;

  cfg = nixos.eval {
    modules = [./default.nix];
    settings = {
      username = "alice";
      userdir = "/home/alice";
    };
  };

  # A derivation's build attributes, read from its .drv (structured-attrs derivations keep
  # everything in one __json entry). The values are compared as text, so the store references
  # they carry are dropped.
  unescape = builtins.replaceStrings ["\\\\" "\\\"" "\\n" "\\r" "\\t"] ["\\" "\"" "\n" "\r" "\t"];
  envOf = aterm: name:
    unescape (builtins.head (lib.splitString "\")])" (builtins.head (lib.splitString "\"),(\""
            (builtins.elemAt (lib.splitString "(\"${name}\",\"" aterm) 1)))));
  readDrv = drvPath: builtins.unsafeDiscardStringContext (builtins.readFile drvPath);
  drvFileAttr = drvPath: attr: let
    aterm = readDrv drvPath;
  in
    if lib.hasInfix "(\"__json\",\"" aterm
    then (builtins.fromJSON (envOf aterm "__json")).${attr}
    else envOf aterm attr;
  # The .drv named `name` that string `str` refers to.
  drvIn = name: str:
    builtins.head (builtins.filter (lib.hasSuffix "-${name}.drv")
      (builtins.attrNames (builtins.getContext str)));
  # The input .drv named `name` of the derivation at `drvPath`.
  inputDrv = name: drvPath: let
    before = builtins.head (lib.splitString "-${name}.drv\"" (readDrv drvPath));
  in
    builtins.substring (builtins.stringLength before - 43) 43 before + "-${name}.drv";

  configToml = builtins.fromTOML (builtins.readFile ./config.toml);
  # Every key the config names, at the top level or one table down.
  configKeys = lib.concatLists (lib.mapAttrsToList (k: v:
    [k]
    ++ (
      if builtins.isAttrs v
      then builtins.attrNames v
      else []
    ))
  configToml);

  linkActivation = cfg.system.activationScripts.linkTealdeerConfig.text;
  seedActivation = cfg.system.activationScripts.seedTealdeerPages.text;
  service = cfg.systemd.user.services.tealdeer-pages-refresh;
  timer = cfg.systemd.user.timers.tealdeer-pages-refresh;

  seedDrv = drvIn "tldr-pages-v2.3-en" seedActivation;
  seedBuild = drvFileAttr seedDrv "buildCommand";
  archiveDrv = inputDrv "tldr-pages.en.zip" seedDrv;
  archiveUrls = drvFileAttr archiveDrv "urls";
  refreshScript = drvFileAttr (drvIn "tealdeer-pages-refresh" service.serviceConfig.ExecStart) "text";

  has = haystack: needle: lib.hasInfix needle haystack;

  # Shell comments explain what the script does NOT do as often as what it does, so an
  # "it never fetches" claim has to look at the commands and not at the prose above them.
  code = text:
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !(lib.hasPrefix "#" (lib.trim l))) (lib.splitString "\n" text));
in
  assay.suite "tealdeer" {
    systemPackages = assay.eq (nixos.hasPackage cfg "tealdeer") true;

    # ---------------------------------------------------------------------------
    # The config
    # ---------------------------------------------------------------------------
    #
    # Every table in tealdeer's config is `deny_unknown_fields`, so a key it does not know is
    # a parse error on every `tldr` and not a warning. These three are the ones the feature
    # takes a position on.
    autoUpdateIsOff = assay.eq configToml.updates.auto_update false;
    # Left at its default so the refresh timer tracks whatever tealdeer calls latest; the pin
    # in default.nix is the seed only.
    namesNoArchiveSource = assay.eq (builtins.elem "archive_source" configKeys) false;
    # Left at its default (warn after 30 days) because the refresh unit swallows its own
    # failures: this warning is the only remaining signal that refreshing has stopped working.
    keepsTheCacheAgeWarning = assay.eq (builtins.elem "warn_cache_age" configKeys) false;

    activationScriptName = assay.eq (cfg.system.activationScripts ? linkTealdeerConfig) true;
    doesNotClaimGenericLinkFile = assay.eq (cfg.system.activationScripts ? linkFile) false;
    # Linked, not copied, from the generated store copy of config.toml.
    linksConfigIntoPlace =
      assay.eq (builtins.match ".*ln -sfn /nix/store/[a-z0-9]+-tealdeer-config\\.toml /home/alice/\\.config/tealdeer/config\\.toml.*" linkActivation != null) true;
    # Activation runs as root; without this the user owns none of their own help config.
    chownsConfigToUser = assay.eq (has linkActivation "chown -R alice:users /home/alice/.config/tealdeer") true;
    # `tldr --seed-config` writes a real file here, and so does a hand-edit.
    keepsAPreExistingRealConfig =
      assay.eq (has linkActivation "mv /home/alice/.config/tealdeer/config.toml /home/alice/.config/tealdeer/config.toml.backup") true;

    # ---------------------------------------------------------------------------
    # The pinned seed
    # ---------------------------------------------------------------------------
    #
    # This is what makes `tldr parted` answer on a host that has never had a network — the
    # installer ISO carries profiles/cli-core.nix too, and a user timer there never fires.
    seedIsPinnedToARelease =
      assay.eq archiveUrls ["https://github.com/tldr-pages/tldr/releases/download/v2.3/tldr-pages.en.zip"];
    # tealdeer's own default archive_source ends in /latest/download. A seed resolved that way
    # would be a different archive on a different day and could not be hashed at all.
    seedIsNotAMovingTarget = assay.eq (builtins.any (u: has u "latest") archiveUrls) false;
    seedIsHashed =
      assay.eq (drvFileAttr archiveDrv "outputHash") "sha256-2mWWVuxb3/VLYxlpLk+bY5EpQJDZgUkyhptMkse2Vlc=";

    # TLDR_PAGES_DIR is the literal "tldr-pages" and Language("en").directory_name() is
    # "pages.en" (tealdeer-1.9.1 src/cache.rs). Get either wrong and the pages are on disk but
    # invisible.
    seedUnpacksIntoPagesEn =
      assay.eq (builtins.match "mkdir -p \\$out/pages\\.en\nunzip -q /nix/store/[a-z0-9]+-tldr-pages\\.en\\.zip -d \\$out/pages\\.en\n" seedBuild != null) true;
    seedLandsInTheCacheTealdeerReads =
      assay.eq (builtins.match ".*cp -r --no-preserve=[^ ]+ /nix/store/[a-z0-9]+-tldr-pages-v2\\.3-en /home/alice/\\.cache/tealdeer/tldr-pages\n.*" seedActivation != null) true;
    # `tldr --update` replaces that directory wholesale, so re-seeding every switch would roll
    # a current cache back to the pinned release.
    seedsOnlyWhenAbsent = assay.eq (has seedActivation "if [ ! -e /home/alice/.cache/tealdeer/tldr-pages ]; then") true;
    # The store copy is read-only, root-owned and stamped 1970. All three have to go: the user
    # must be able to let `tldr --update` replace it, and a 1970 mtime reads as an ancient
    # cache to `cache.age()`.
    seedIsMadeWritable =
      assay.eq (has seedActivation "cp -r --no-preserve=mode,ownership,timestamps ") true;
    seedChownsToUser = assay.eq (has seedActivation "chown -R alice:users /home/alice/.cache/tealdeer/tldr-pages") true;

    # The whole point of the seed is that switching a host does not depend on the network.
    # Nothing in either activation script may fetch.
    activationNeverFetches =
      assay.eq
      (lib.any (needle: has (code linkActivation + code seedActivation) needle) [
        "curl"
        "wget"
        "tldr --update"
        "https://"
      ])
      false;

    # ---------------------------------------------------------------------------
    # The refresh timer
    # ---------------------------------------------------------------------------
    refreshTimerExists = assay.eq (cfg.systemd.user.timers ? tealdeer-pages-refresh) true;
    refreshServiceIsOneshot = assay.eq service.serviceConfig.Type "oneshot";
    refreshUpdatesThePages =
      assay.eq (builtins.match ".*if ! /nix/store/[a-z0-9]+-tealdeer-[^/]+/bin/tldr --update --quiet; then.*" refreshScript != null) true;
    # A refresh that cannot reach the network is "the pages are a week older than they could
    # be", not a failed unit: activation already left a cache behind, and a laptop that was
    # merely off the network must not show a red user unit after every boot.
    refreshFailureIsNotAFailedUnit =
      assay.eq [(has refreshScript "page refresh failed") (has (code refreshScript) "exit")] [true false];
    # tealdeer resolves config and cache against the XDG variables, and a systemd user manager
    # sets neither of those two.
    refreshDoesNotInheritXdgPaths = assay.eq service.serviceConfig.Environment [
      "HOME=/home/alice"
      "XDG_CONFIG_HOME=/home/alice/.config"
      "XDG_CACHE_HOME=/home/alice/.cache"
    ];
    timerIsWanted = assay.eq timer.wantedBy ["timers.target"];
    timerIsWeekly = assay.eq timer.timerConfig.OnCalendar "weekly";
    # Also how a host that has never refreshed gets past the pinned seed: Persistent fires the
    # missed window shortly after the first boot.
    timerCatchesUp = assay.eq timer.timerConfig.Persistent true;
    # One GitHub release asset, a whole fleet. Spread it out.
    timerIsSpreadOut = assay.eq timer.timerConfig.RandomizedDelaySec "6h";
    # features/cli/nixos-update-notifier wants and follows graphical-session.target because it
    # draws a notification. This unit only writes files, and huginn / mimir / muninn / the
    # installer never start a graphical session — which is exactly where offline help matters
    # most. So the unit declares no session ordering at all, the same as
    # features/cli/atuin's shell-history-checkpoint.
    needsNoGraphicalSession = assay.eq [service.wants service.after] [[] []];
  }
