# Assay: NFS client utilities for fleet mounts (drakkar, huginn).
#
# The feature installs nfs-utils (mount.nfs) and nothing else: it neither mounts anything
# nor opens a port. Claims read the evaluated config.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./default.nix];};
in
  assay.suite "nfs-client" {
    hasNfsUtils = assay.eq (nixos.hasPackage cfg "nfs-utils") true;
    notAnNfsServer = assay.eq cfg.services.nfs.server.enable false;
    mountsNothing = assay.eq (builtins.attrNames cfg.fileSystems) (builtins.attrNames nixos.baseline.fileSystems);
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
    noUDPPortsOpened = assay.eq (nixos.openUDPPorts cfg) (nixos.openUDPPorts nixos.baseline);
  }
