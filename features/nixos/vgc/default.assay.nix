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
    # Same retention as the stock unit.
    keeps30Days = assay.eq (lib.hasSuffix "/bin/vgc run --delete-older-than 30d" svc.serviceConfig.ExecStart) true;
    # The standing oracle comparison: monthly, read-only.
    checksAgainstNixMonthly =
      assay.eq [cfg.systemd.services.vgc-check.startAt (lib.hasSuffix "/bin/vgc check" cfg.systemd.services.vgc-check.serviceConfig.ExecStart)] [["monthly"] true];
    # vgc delegates to nix-env / nix-store / nix: the daemon's own Nix must be on PATH.
    hasTheSystemNixOnPath = assay.eq (builtins.elem cfg.nix.package svc.path) true;
    # vgc remounts the store writable in its own namespace (as Nix does); the unit
    # must not hide that namespace behind a read-only ProtectSystem.
    leavesTheStoreToVgc = assay.eq (svc.serviceConfig ? ProtectSystem) false;
    # Nix clients wait while it holds the GC lock, so it is not starved to idle IO.
    schedulingWhileHoldingTheLock = assay.eq [svc.serviceConfig.Nice svc.serviceConfig.IOSchedulingClass] [10 "best-effort"];

    installsTheVgcPackage =
      assay.eq (builtins.any (p: (p.pname or "") == "vgc") cfg.environment.systemPackages) true;
  }
