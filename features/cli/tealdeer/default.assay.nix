# Colocated suite: tealdeer as the offline help owner.
#
# The facts worth pinning here are the ones a later wave can break without noticing: that no
# part of this feature reaches the network during activation, that the seed is pinned to a
# release rather than to `latest`, that it lands in the one directory tealdeer actually reads,
# that it never overwrites a cache the user has since refreshed, and that the refresh unit
# needs no graphical session because most of this fleet never starts one.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = import <nixpkgs> {};
  nixpkgsLib = pkgs.lib;

  src = builtins.readFile ./default.nix;
  configToml = builtins.readFile ./config.toml;

  # No options, so no evalModules: the module is a plain function of pkgs and settings.
  mod = import ./default.nix {
    inherit pkgs;
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
  };

  linkActivation = mod.system.activationScripts.linkTealdeerConfig.text;
  seedActivation = mod.system.activationScripts.seedTealdeerPages.text;
  service = mod.systemd.user.services.tealdeer-pages-refresh;
  timer = mod.systemd.user.timers.tealdeer-pages-refresh;

  has = haystack: needle: nixpkgsLib.hasInfix needle haystack;

  lines = text: nixpkgsLib.splitString "\n" text;

  # Shell comments explain what the script does NOT do as often as what it does, so an
  # "it never fetches" claim has to look at the commands and not at the prose above them.
  code = text:
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !(nixpkgsLib.hasPrefix "#" (nixpkgsLib.trim l))) (lines text));

  # The one line in default.nix that names an upstream archive. The header comment says
  # "releases/latest/download" when describing tealdeer's own default, which is why this
  # matches on "releases/download" rather than on the word "latest".
  archiveUrlLine =
    builtins.head (builtins.filter (l: nixpkgsLib.hasInfix "releases/download" l) (lines src));
in
  assay.suite "tealdeer" {
    systemPackages = assay.eq (map nixpkgsLib.getName mod.environment.systemPackages) ["tealdeer"];

    # ---------------------------------------------------------------------------
    # The config
    # ---------------------------------------------------------------------------
    #
    # Every table in tealdeer's config is `deny_unknown_fields`, so a key it does not know is
    # a parse error on every `tldr` and not a warning. These three are the ones the feature
    # takes a position on.
    autoUpdateIsOff = assay.eq (has configToml "auto_update = false") true;
    # Left at its default so the refresh timer tracks whatever tealdeer calls latest; the pin
    # in default.nix is the seed only.
    namesNoArchiveSource = assay.eq (has configToml "archive_source =") false;
    # Left at its default (warn after 30 days) because the refresh unit swallows its own
    # failures: this warning is the only remaining signal that refreshing has stopped working.
    keepsTheCacheAgeWarning = assay.eq (has configToml "warn_cache_age =") false;

    activationScriptName = assay.eq (mod.system.activationScripts ? linkTealdeerConfig) true;
    doesNotClaimGenericLinkFile = assay.eq (mod.system.activationScripts ? linkFile) false;
    linksConfigIntoPlace = assay.eq (has linkActivation "/home/alice/.config/tealdeer/config.toml") true;
    linksRatherThanCopies = assay.eq (has linkActivation "ln -sfn") true;
    # Activation runs as root; without this the user owns none of their own help config.
    chownsConfigToUser = assay.eq (has linkActivation "chown -R alice:users") true;
    # `tldr --seed-config` writes a real file here, and so does a hand-edit.
    keepsAPreExistingRealConfig = assay.eq (has linkActivation "config.toml.backup") true;

    # ---------------------------------------------------------------------------
    # The pinned seed
    # ---------------------------------------------------------------------------
    #
    # This is what makes `tldr parted` answer on a host that has never had a network — the
    # installer ISO carries profiles/cli-core.nix too, and a user timer there never fires.
    seedIsPinnedToARelease =
      assay.eq (has archiveUrlLine "\${pagesRelease}/tldr-pages.en.zip") true;
    pagesReleaseIsATag = assay.eq (has src "pagesRelease = \"v2.3\"") true;
    # tealdeer's own default archive_source ends in /latest/download. A seed resolved that way
    # would be a different archive on a different day and could not be hashed at all.
    seedIsNotAMovingTarget = assay.eq (has archiveUrlLine "latest") false;
    seedIsHashed = assay.eq (has src "sha256-") true;

    # TLDR_PAGES_DIR is the literal "tldr-pages" and Language("en").directory_name() is
    # "pages.en" (tealdeer-1.9.1 src/cache.rs). Get either wrong and the pages are on disk but
    # invisible.
    seedUnpacksIntoPagesEn = assay.eq (has src "mkdir -p $out/pages.en") true;
    seedLandsInTheCacheTealdeerReads =
      assay.eq (has seedActivation "/home/alice/.cache/tealdeer/tldr-pages") true;
    # `tldr --update` replaces that directory wholesale, so re-seeding every switch would roll
    # a current cache back to the pinned release.
    seedsOnlyWhenAbsent = assay.eq (has seedActivation "[ ! -e ") true;
    # The store copy is read-only, root-owned and stamped 1970. All three have to go: the user
    # must be able to let `tldr --update` replace it, and a 1970 mtime reads as an ancient
    # cache to `cache.age()`.
    seedIsMadeWritable =
      assay.eq (has seedActivation "--no-preserve=mode,ownership,timestamps") true;
    seedChownsToUser = assay.eq (has seedActivation "chown -R alice:users") true;

    # The whole point of the seed is that switching a host does not depend on the network.
    # Nothing in either activation script may fetch.
    activationNeverFetches =
      assay.eq
      (nixpkgsLib.any (needle: has (code linkActivation + code seedActivation) needle) [
        "curl"
        "wget"
        "tldr --update"
        "https://"
      ])
      false;

    # ---------------------------------------------------------------------------
    # The refresh timer
    # ---------------------------------------------------------------------------
    refreshTimerExists = assay.eq (mod.systemd.user.timers ? tealdeer-pages-refresh) true;
    refreshServiceIsOneshot = assay.eq service.serviceConfig.Type "oneshot";
    refreshUpdatesThePages = assay.eq (has src "tldr --update --quiet") true;
    # A refresh that cannot reach the network is "the pages are a week older than they could
    # be", not a failed unit: activation already left a cache behind, and a laptop that was
    # merely off the network must not show a red user unit after every boot.
    refreshFailureIsNotAFailedUnit = assay.eq (has src "page refresh failed") true;
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
    needsNoGraphicalSession = assay.eq [(service ? wants) (service ? after)] [false false];
  }
