# Homarr dashboard (official container image) — port 7575.
#
# Reverted from the vendored from-source build (nixpkgs PR #430235 packaging):
# its better-sqlite3 native module SIGABRTs under the bundled Node 24
# (`Statement::~Statement` -> `node::RemoveEnvironmentCleanupHook` assert),
# crash-looping homarr.service. The upstream OCI image is the supported
# runtime; data lives under /data/services/homarr/{data,appdata} as before.
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
  systemd.tmpfiles.rules = [
    "d ${directoryPath}/data 0770 homarr data - -"
    "d ${directoryPath}/appdata 0770 homarr data - -"
  ];

  networking.firewall.allowedTCPPorts = [7575];
}
