# Assay: NFS client for fleet bulk storage (drakkar, huginn mount mimir's /data).
#
# The feature installs nfs-utils and declares one on-demand mount of the "nfs-server" host's
# /data at /mnt/<server>. It never opens a port and is never itself a server. Claims read
# the evaluated config.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  fleet = import ../../../common/fleet.nix;
  cfg = nixos.eval {modules = [./default.nix];};
  mount = cfg.fileSystems."/mnt/mimir";
  hasOpt = o: builtins.elem o mount.options;
in
  assay.suite "nfs-client" {
    hasNfsUtils = assay.eq (nixos.hasPackage cfg "nfs-utils") true;
    notAnNfsServer = assay.eq cfg.services.nfs.server.enable false;

    # The one mount: mimir's /data, by the tailnet address fleet.nix records, over NFSv4.2.
    mountsServerData = assay.eq {inherit (mount) device fsType;} {
      device = "${fleet.hosts.mimir.tailscaleIp}:/data";
      fsType = "nfs";
    };
    onlyThatMount =
      assay.eq (builtins.attrNames cfg.fileSystems)
      (builtins.attrNames (nixos.baseline.fileSystems // {"/mnt/mimir" = null;}));
    usesNfs42 = assay.eq (hasOpt "nfsvers=4.2") true;

    # An offline mimir must not block boot or hang a shell: on-demand, non-fatal, bounded.
    mountsOnDemand = assay.eq (map hasOpt ["noauto" "x-systemd.automount"]) [true true];
    neverFailsBoot = assay.eq (hasOpt "nofail") true;
    boundedWait = assay.eq (hasOpt "x-systemd.mount-timeout=15s") true;

    # Read-write is the point of the share; `ro` here would reproduce "can't write to /mnt/mimir".
    notReadOnly = assay.eq (hasOpt "ro") false;

    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
    noUDPPortsOpened = assay.eq (nixos.openUDPPorts cfg) (nixos.openUDPPorts nixos.baseline);
  }
