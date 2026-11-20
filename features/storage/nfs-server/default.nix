# NFS server for fleet bulk storage (Mimir /data).
{lib, ...}: let
  fleet = import ../../../common/fleet.nix;
  # Tailscale IPv4 of every "nfs-client" host in common/fleet.nix.
  clientHosts = map (name: "${fleet.hosts.${name}.tailscaleIp}/32") fleet.nfsClients;

  exportOptions = "rw,sync,no_subtree_check,sec=sys";

  clientExports = lib.concatMapStringsSep " " (host: "${host}(${exportOptions})") clientHosts;
in {
  services.nfs.server = {
    enable = true;
    exports = ''
      /data ${clientExports}
    '';
  };

  # NFS over Tailscale only (no WAN exposure).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    111
    2049
    20048
  ];
}
