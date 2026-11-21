# Assay: vgen takes over generation retention from vgc's `--delete-older-than 30d`.
#
# Evaluated with both features wrapped as a host has them (lib/features.nix), because
# what matters is the interplay: with vgen on, the prune runs before every vgc run with
# vgc's old policy and vgc stops pruning; with vgen forced off, vgc's flag is back.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../../../lib/features.nix {inherit lib;};

  eval = selection:
    (nixos.evalSystem {
      modules = [../default.nix (features.feature ../vgc) (features.feature ./.) selection];
    })
    .config;
  cfg = eval {
    features.nixos.vgc.enable = true;
    features.nixos.vgen.enable = true;
  };
  # The rollback, as a host would write it.
  rolledBack = eval {
    features.nixos.vgc.enable = true;
    features.nixos.vgen.enable = lib.mkForce false;
  };
  alone = eval {features.nixos.vgen.enable = true;};

  prune = cfg.systemd.services.vgen-prune;
  vgcExec = c: c.systemd.services.vgc.serviceConfig.ExecStart;
in
  assay.suite "vgen" {
    # Every vgc run (its weekly timer, or by hand) brings the prune in first.
    prunesBeforeEveryVgcRun = assay.eq [prune.wantedBy prune.before] [["vgc.service"] ["vgc.service"]];
    isOneshot = assay.eq prune.serviceConfig.Type "oneshot";
    # vgc's old policy over vgc's old set of profiles.
    thirtyDaysOverEveryProfile =
      assay.eq (lib.hasSuffix "/bin/vgen prune --all-profiles --keep-days 30" prune.serviceConfig.ExecStart) true;
    vgcOnlyCollects = assay.eq (lib.hasSuffix "/bin/vgc run" (vgcExec cfg)) true;
    # vgc's timer drives it, so it has none of its own beside vgc...
    noTimerBesideVgc = assay.eq [(cfg.systemd.timers ? vgen-prune) prune.startAt] [false []];
    # ...and keeps the weekly schedule without vgc.
    weeklyWithoutVgc =
      assay.eq [alone.systemd.services.vgen-prune.startAt alone.systemd.timers.vgen-prune.timerConfig.Persistent] [["weekly"] true];

    # One option rolls back: vgen off puts vgc's flag back and drops the prune unit.
    rollbackRestoresVgcsFlag =
      assay.eq [(lib.hasSuffix "/bin/vgc run --delete-older-than 30d" (vgcExec rolledBack)) (rolledBack.systemd.services ? vgen-prune)] [true false];

    # Pins live where vgc's root scan finds them.
    pinDirectory = assay.eq (builtins.elem "d /nix/var/nix/gcroots/vgen 0755 root root - -" cfg.systemd.tmpfiles.rules) true;
    installsTheVgenPackage =
      assay.eq (builtins.any (p: (p.pname or "") == "vgen") cfg.environment.systemPackages) true;
  }
