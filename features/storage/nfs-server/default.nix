# NFS server for fleet bulk storage (Mimir /data).
{
  lib,
  ...
}: let
  # Tailscale IPv4 of Drakkar and Huginn — clients for /data exports.
  clientHosts = [
    "100.69.213.35/32" # drakkar
    "100.70.136.13/32" # huginn
  ];

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
