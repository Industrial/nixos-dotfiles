# Assay: vgc takes over the weekly GC from nix-collect-garbage.
#
# Evaluated together with the base nixos feature, because what matters is the
# interplay: the stock nix-gc schedule must go away exactly when vgc's arrives,
# with the same cadence and retention.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = (nixos.evalSystem {modules = [../default.nix ./default.nix];}).config;
  svc = cfg.systemd.services.vgc;
in
  assay.suite "vgc" {
    stockGcIsOff = assay.eq cfg.nix.gc.automatic false;
    stockGcTimerIsGone = assay.eq (cfg.systemd.timers ? nix-gc) false;

    runsWeekly = assay.eq svc.startAt ["weekly"];
    catchesUpAfterDowntime = assay.eq cfg.systemd.timers.vgc.timerConfig.Persistent true;
    isOneshot = assay.eq svc.serviceConfig.Type "oneshot";
    # Same retention as the stock unit, and verified against Nix's own dead set.
    keeps30DaysAndVerifies =
      assay.eq (lib.hasSuffix "/bin/vgc run --delete-older-than 30d --verify" svc.serviceConfig.ExecStart) true;
    # vgc delegates to nix-env / nix-store / nix: the daemon's own Nix must be on PATH.
    hasTheSystemNixOnPath = assay.eq (builtins.elem cfg.nix.package svc.path) true;
    staysOutOfTheWay = assay.eq [svc.serviceConfig.Nice svc.serviceConfig.IOSchedulingClass] [19 "idle"];

    installsTheVgcPackage =
      assay.eq (builtins.any (p: (p.pname or "") == "vgc") cfg.environment.systemPackages) true;
  }
