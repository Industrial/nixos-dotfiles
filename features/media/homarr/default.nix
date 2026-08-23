# Homarr dashboard (official container image) — port 7575.
# The previous in-repo module ran `npm start` from an empty directory and
# never provisioned application code; nixpkgs has no homarr package or
# services.homarr module, so run the upstream OCI image instead.
{pkgs, ...}: let
  name = "homarr";
  directoryPath = "/data/services/${name}";
in {
  virtualisation.oci-containers.containers.${name} = {
    image = "ghcr.io/homarr-labs/homarr:latest";
    ports = ["7575:7575"];
    environment = {
      SECRET_ENCRYPTION_KEY = "a203bd976170059a5b560b8ade34fcb4951f970f94792abefbafad1377610d28";
    };
    volumes = [
      "${directoryPath}/data:/data"
      "${directoryPath}/appdata:/appdata"
    ];
  };

  # Container data lives under the fleet-standard NFS-backed path.
  systemd = {
    tmpfiles.rules = [
      "d ${directoryPath}/data 0755 root root - -"
      "d ${directoryPath}/appdata 0755 root root - -"
    ];
  };

  networking.firewall.allowedTCPPorts = [7575];
}
