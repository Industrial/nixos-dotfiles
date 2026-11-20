# Colocated suite: module top-level shape with stubbed args, plus the store and journal
# maintenance this module and features/nixos/default.nix produce together once evaluated.
let
  assay = import ./../../../common/assay/default.nix;
  inherit (import <nixpkgs> {}) lib;
  settings = {
    hostname = "testhost";
    username = "alice";
    useremail = "a@b.c";
    stateVersion = "25.05";
    hostPlatform = "x86_64-linux";
  };
  mod = import ./default.nix {
    inherit settings lib;
    pkgs = {
      callPackage = path: args: "pkg";
      stdenv = {
        mkDerivation = args: args.name or args.pname or "drv";
        hostPlatform = {system = "x86_64-linux";};
      };
      fish = "fish";
      writeShellScript = name: text: name;
      writeText = name: text: name;
    };
    config = {};
  };

  # The two modules that between them own store GC, store dedup and the journal cap, as a
  # real NixOS evaluation rather than their literal attrsets.
  evaluated = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    specialArgs = {inherit settings;};
    modules = [
      ./default.nix
      ./../default.nix
      {
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
      }
    ];
  };
  inherit (evaluated) config;
  gcOptions = config.nix.gc.options;
in
  assay.suite "systemd" {
    shape = assay.hasAttrs mod ["systemd" "services"];

    # Maintenance used to run from cron. Nothing needs the daemon any more.
    noCronDaemon = assay.eq config.services.cron.enable false;
    noCronJobs = assay.eq config.services.cron.systemCronJobs [];

    # GC runs from nix.gc's systemd timer and keeps a rollback window. The old nightly
    # `nix-collect-garbage -d` deleted every generation but the current one.
    gcIsAutomatic = assay.eq config.nix.gc.automatic true;
    gcHasTimer = assay.eq (config.systemd.timers ? nix-gc) true;
    gcKeepsRollbacks = assay.eq (builtins.match ".*--delete-older-than [0-9]+d.*" gcOptions != null) true;
    gcDoesNotDeleteAllGenerations =
      assay.eq (builtins.match "(.* )?(-d|--delete-old)( .*)?" gcOptions != null) false;

    # Exactly one store-dedup mechanism: hard-linking at build time. A scheduled
    # `nix-store --optimise` on top of it only rescans what is already deduplicated.
    optimiseAtBuildTime = assay.eq config.nix.settings.auto-optimise-store true;
    noScheduledOptimise = assay.eq config.nix.optimise.automatic false;

    # The journal is capped by journald itself, continuously, not vacuumed weekly.
    journalCapped = assay.eq config.services.journald.settings.Journal.SystemMaxUse "1G";
  }
