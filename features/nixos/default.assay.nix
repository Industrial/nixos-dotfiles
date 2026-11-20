# Assay: the base NixOS feature -- locale, nix daemon policy, nixpkgs config and overlays,
# journald caps.
#
# Claims read the evaluated config (and, for the overlays, the evaluated package set), so they
# hold however the values are produced. The binary-cache trust set is security-relevant: every
# key here can sign store paths this machine will accept, so it is pinned exactly.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;
  sys = nixos.evalSystem {modules = [./default.nix];};
  cfg = sys.config;
  inherit (sys) pkgs;
  ns = cfg.nix.settings;
  # NixOS itself also contributes cache.nixos.org; what matters is the set that is trusted.
  asSet = l: lib.sort lib.lessThan (lib.unique (map (lib.removeSuffix "/") l));
in
  assay.suite "nixos" {
    # Pre-generated, so pressure-vessel/steamrt does not regenerate locales per game launch.
    defaultLocaleIsEnUsUtf8 = assay.eq cfg.i18n.defaultLocale "en_US.UTF-8";
    supportedLocales = assay.eq cfg.i18n.supportedLocales ["en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8"];
    stateVersionFromSettings = assay.eq cfg.system.stateVersion nixos.defaultSettings.stateVersion;
    hostPlatformFromSettings = assay.eq cfg.nixpkgs.hostPlatform.system nixos.defaultSettings.hostPlatform.system;

    substitutersAreExactlyTheThreeCaches =
      assay.eq (asSet ns.substituters)
      ["https://cache.nixos.org" "https://devenv.cachix.org" "https://nix-community.cachix.org"];
    trustsExactlyTheThreeCacheKeys =
      assay.eq (asSet ns.trusted-public-keys)
      [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    buildsAreSandboxed = assay.eq ns.sandbox true;
    flakesEnabled = assay.eq ns.experimental-features ["nix-command" "flakes"];
    # Big builds go to disk, not the tmpfs /tmp.
    buildDirOffTmpfs = assay.eq ns.build-dir "/var/temproot";
    buildTimeoutOneHour = assay.eq ns.build-timeout 3600;
    autoOptimisesStore = assay.eq ns.auto-optimise-store true;
    keepsOutputsAndDerivations = assay.eq [ns.keep-outputs ns.keep-derivations] [true true];

    gcWeeklyKeeps30Days =
      assay.eq {inherit (cfg.nix.gc) automatic dates options;}
      {
        automatic = true;
        dates = ["weekly"];
        options = "--delete-older-than 30d";
      };

    allowsUnfree = assay.eq cfg.nixpkgs.config.allowUnfree true;
    # The only insecure package let through, for some gaming applications.
    permitsOnlyMbedtls2 = assay.eq cfg.nixpkgs.config.permittedInsecurePackages ["mbedtls-2.28.10"];

    # The overlays, observed on the package set they produce.
    openldapChecksOff = assay.eq pkgs.openldap.doCheck false;
    pipxChecksOff = assay.eq [pkgs.pipx.doCheck pkgs.python314Packages.pipx.doCheck] [false false];
    rustPackagesBuildVendoredCLibs =
      assay.eq
      (map (p: p.dontCargoUseSystemLibs or false)
        [pkgs.rusty-path-of-building pkgs.slumber pkgs.ashell pkgs.nushellPlugins.polars])
      [true true true true];

    # A runaway user unit cannot fill /var/log/journal and break dbus-broker reloads.
    journalCapped =
      assay.subset cfg.services.journald.settings.Journal
      {
        SystemMaxUse = "1G";
        RuntimeMaxUse = "256M";
        MaxFileSec = "1week";
      };
  }
