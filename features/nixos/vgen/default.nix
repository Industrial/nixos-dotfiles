# vgen (rust/tools/vgen) takes over Nix generation management: listing, pinning and the
# weekly prune, which used to be vgc's `--delete-older-than 30d` (nix-env
# --delete-generations underneath) with the boot menu left stale until the next switch.
#
# Retention (agreed with vgc's owner, GH-190): vgen owns the profiles, generations and
# boot entries; vgc owns the roots and the collection. `vgen-prune` runs before every
# vgc run (wanted by and ordered before vgc.service), with vgc's old policy: 30 days, by
# Nix's own rule (nix-store-core's `generations`, lifted from vgc), over the same profiles
# (`--all-profiles`). Unlike the flag it replaces, it never removes a profile's current
# generation, the booted one, the running one, the one the boot menu defaults to (in
# either profile: comin's or `system`) or a pinned one, and when a system profile loses
# generations it rewrites the boot entries through the system's own installer
# (`switch-to-configuration boot`), never by editing /boot, keeping that default.
#
# Pins are GC roots under /nix/var/nix/gcroots/vgen/ (`vgen pin <n>`); vgc and Nix walk
# gcroots recursively, so they honour them as they are.
#
# Rollback: `features.nixos.vgen.enable = lib.mkForce false;`. features/nixos/vgc then
# puts `--delete-older-than 30d` back on its ExecStart, and bin/generations falls back to
# nix-env.
#
# Health probe (on the host):
#   systemctl show -p Result vgen-prune | grep -qx Result=success && vgen list --no-diff
{
  config,
  lib,
  pkgs,
  ...
}: let
  vgen = pkgs.callPackage ../../../rust/tools/vgen {};
  # With vgc on, vgc's weekly timer brings the prune in; without it, the prune keeps
  # the same weekly schedule on a timer of its own.
  vgcOn = config.features.nixos.vgc.enable or false;
in {
  environment.systemPackages = [vgen];

  systemd.tmpfiles.rules = ["d /nix/var/nix/gcroots/vgen 0755 root root - -"];

  systemd.services.vgen-prune = {
    description = "Prune Nix profile generations older than 30 days, boot entries in step (vgen)";
    # Generations first: removing them is what turns their closures into garbage.
    wantedBy = ["vgc.service"];
    before = ["vgc.service"];
    startAt = lib.mkIf (!vgcOn) "weekly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe vgen} prune --all-profiles --keep-days 30";
      Nice = 10;
      IOSchedulingClass = "best-effort";
    };
  };

  systemd.timers.vgen-prune = lib.mkIf (!vgcOn) {timerConfig.Persistent = true;};
}
