# Assay: systemd tuning, plus the store and journal maintenance this module and
# features/nixos/default.nix produce together once evaluated.
#
# Store maintenance used to run from cron here (`nix-collect-garbage -d` nightly, which
# deleted every rollback generation, a redundant `nix-store --optimise`, and a journal vacuum
# that contradicted journald's own cap). These claims read the evaluated config, so they hold
# however the values are produced.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix ./../default.nix];};
  gcOptions = cfg.nix.gc.options;

  # The module's literal attrset, for claims about what it declares itself.
  mod = import ./default.nix {
    inherit lib;
    settings = nixos.defaultSettings;
    pkgs = {};
    config = {};
  };
in
  assay.suite "systemd" {
    # Nothing schedules through cron any more, so the daemon is not running.
    noCronDaemon = assay.eq cfg.services.cron.enable false;
    noCronJobs = assay.eq cfg.services.cron.systemCronJobs [];

    # GC runs from nix.gc's systemd timer and keeps a rollback window.
    gcIsAutomatic = assay.eq cfg.nix.gc.automatic true;
    gcHasTimer = assay.eq (cfg.systemd.timers ? nix-gc) true;
    gcKeepsRollbacks = assay.eq (builtins.match ".*--delete-older-than [0-9]+d.*" gcOptions != null) true;
    gcDoesNotDeleteAllGenerations =
      assay.eq (builtins.match "(.* )?(-d|--delete-old)( .*)?" gcOptions != null) false;

    # Exactly one store-dedup mechanism: hard-linking at build time. A scheduled
    # `nix-store --optimise` on top of it only rescans what is already deduplicated.
    optimiseAtBuildTime = assay.eq cfg.nix.settings.auto-optimise-store true;
    noScheduledOptimise = assay.eq cfg.nix.optimise.automatic false;

    # The journal is capped by journald itself, continuously, not vacuumed weekly.
    journalCapped = assay.eq cfg.services.journald.settings.Journal.SystemMaxUse "1G";

    # systemd-oomd belongs to features/performance/memory; declaring it here too was a
    # second, silently-agreeing definition. (NixOS enables oomd by default, so the
    # evaluated value cannot tell the two apart; the module's own attrset can.)
    oomdNotDeclaredHere = assay.eq (mod.systemd ? oomd) false;

    # The rest of what this module is for.
    dbusBrokerNotRestartedOnSwitch =
      assay.eq [cfg.systemd.services.dbus-broker.restartIfChanged cfg.systemd.services.dbus-broker.reloadIfChanged] [false false];
    displayManagerNotRestartedOnSwitch = assay.eq cfg.systemd.services.display-manager.restartIfChanged false;
    timesyncdOn = assay.eq cfg.services.timesyncd.enable true;
  }
