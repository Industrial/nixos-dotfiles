# Colocated suite for hosts/muninn/filesystems.nix.
#
# muninn is the work laptop and holds no personal files, so it must not mount mimir's /data
# (mimir does not export to it either — common/fleet.assay.nix checks that the two agree).
# The module is deliberately empty; these claims catch a mount re-added by habit, through
# this module or any feature it pulls in. Everything else muninn mounts comes from ./disko.nix.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./filesystems.nix];
    settings.hostname = "muninn";
  };
  nfsMounts = builtins.filter (fs: builtins.elem fs.fsType ["nfs" "nfs4"]) (builtins.attrValues cfg.fileSystems);
in
  assay.suite "muninn-filesystems" {
    addsNoMounts = assay.eq (builtins.attrNames cfg.fileSystems) (builtins.attrNames nixos.baseline.fileSystems);
    noMimirMount = assay.eq (cfg.fileSystems ? "/mnt/mimir") false;
    noNfsMounts = assay.eq nfsMounts [];
    noNfsClientSupport = assay.eq (cfg.boot.supportedFilesystems.nfs4 or false) false;
    addsNoSwap = assay.eq cfg.swapDevices [];
  }
