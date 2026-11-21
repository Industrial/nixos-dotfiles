# vgc takes over the weekly Nix garbage collection from nix-collect-garbage.
#
# Same schedule and retention as the stock `nix.gc` (features/nixos/default.nix:
# weekly, --delete-older-than 30d), which this switches off. vgc prunes the old
# generations with nix-env, then takes Nix's GC lock, works out the dead set
# itself (rust/tools/vgc, Voltaic), invalidates it in the store database and
# deletes it, then prunes /nix/store/.links. vgc-check compares its dead set with
# Nix's every month. Disable the feature to get the stock unit back.
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
      ExecStart = "${lib.getExe vgc} run --delete-older-than 30d";
      # /nix/store is a read-only bind mount. vgc makes it writable for itself
      # the way Nix does (private mount namespace + bind remount, src/mounts.vlt),
      # so the unit needs no mount options and the host keeps a read-only store.
      # vgc holds the GC lock while it deletes, and Nix clients wait for it:
      # don't let it be starved behind interactive work while they do.
      Nice = 10;
      IOSchedulingClass = "best-effort";
    };
  };

  # A run missed while the machine was off happens at the next boot, as nix-gc's did.
  systemd.timers.vgc.timerConfig.Persistent = true;

  # The standing correctness check: once a month, compare vgc's dead set with
  # `nix-store --gc --print-dead` and log the difference (exit 1 on any). It
  # deletes nothing itself. The weekly run skips `--verify` because asking Nix
  # costs its full ~2.5 min scan, the very cost vgc removes.
  systemd.services.vgc-check = {
    description = "Compare vgc's dead set with Nix's (read-only)";
    path = [config.nix.package];
    startAt = "monthly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe vgc} check";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.vgc-check.timerConfig.Persistent = true;
}
