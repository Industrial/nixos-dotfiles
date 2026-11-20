# Colocated suite for hosts/huginn/filesystems.nix.
#
# The module is deliberately empty: the mimir NFS mount was removed while mimir is down, and
# everything else huginn mounts comes from ./disko.nix. A remote mount re-added while its server
# is unreachable can stall boot or session start, so "adds nothing" is the promise to guard.
# Re-adding the mount should come with claims here that it is an on-demand systemd automount,
# nofail, with a short timeout, so a down mimir cannot hold up boot.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./filesystems.nix];
    settings.hostname = "huginn";
  };
in
  assay.suite "huginn-filesystems" {
    addsNoMounts = assay.eq (builtins.attrNames cfg.fileSystems) (builtins.attrNames nixos.baseline.fileSystems);
    addsNoSwap = assay.eq cfg.swapDevices [];
  }
