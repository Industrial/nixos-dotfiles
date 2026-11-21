# vgc takes over the weekly Nix garbage collection from nix-collect-garbage.
#
# Same schedule and retention as the stock `nix.gc` (features/nixos/default.nix:
# weekly, --delete-older-than 30d), which this switches off. vgc prunes the old
# generations, works out the dead set itself (rust/tools/vgc, Voltaic), and hands
# it to `nix store delete --skip-alive`, so Nix re-checks every path under its own
# GC lock before deleting it. `--verify` additionally asks Nix for its dead set
# and deletes only what both agree on; the journal records both counts, which is
# the release evidence for this piece. Disable the feature to get the stock unit
# back.
{
  config,
  lib,
  pkgs,
  ...
}: let
  vgc = pkgs.callPackage ../../../rust/tools/vgc {};
in {
  nix.gc.automatic = lib.mkForce false;

  environment.systemPackages = [vgc];

  systemd.services.vgc = {
    description = "Nix garbage collection (vgc)";
    # nix-env, nix-store and nix: vgc delegates generation removal and deletion.
    path = [config.nix.package];
    startAt = "weekly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe vgc} run --delete-older-than 30d --verify";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  # A run missed while the machine was off happens at the next boot, as nix-gc's did.
  systemd.timers.vgc.timerConfig.Persistent = true;
}
