# Assay: vopt takes over deduplication from auto-optimise-store.
#
# Evaluated together with the base nixos feature: inline optimisation must go off
# exactly when vopt's schedule arrives.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = (nixos.evalSystem {modules = [../default.nix ./default.nix];}).config;
  svc = cfg.systemd.services.vopt;
in
  assay.suite "vopt" {
    inlineOptimisationIsOff = assay.eq cfg.nix.settings.auto-optimise-store false;
    runsDaily = assay.eq svc.startAt ["daily"];
    catchesUpAfterDowntime = assay.eq cfg.systemd.timers.vopt.timerConfig.Persistent true;
    isOneshot = assay.eq svc.serviceConfig.Type "oneshot";
    runsIncrementally = assay.eq (lib.hasSuffix "/bin/vopt run" svc.serviceConfig.ExecStart) true;
    # The last-run marker lives in the unit's state directory, /var/lib/vopt.
    keepsItsStateInVarLib = assay.eq svc.serviceConfig.StateDirectory "vopt";
    staysOutOfTheWay = assay.eq [svc.serviceConfig.Nice svc.serviceConfig.IOSchedulingClass] [19 "idle"];
    installsTheVoptPackage =
      assay.eq (builtins.any (p: (p.pname or "") == "vopt") cfg.environment.systemPackages) true;
  }
