# Colocated suite for features/media/homarr/default.nix.
# Guards the OCI-container implementation (the earlier in-repo module ran
# `npm start` from an empty directory and never worked).
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {};
    lib = {};
    config = {};
  };
  container = mod.virtualisation.oci-containers.containers.homarr;
  rules = builtins.concatStringsSep "\n" mod.systemd.tmpfiles.rules;
in
  assay.suite "homarr" {
    usesUpstreamOciImage =
      assay.eq container.image "ghcr.io/homarr-labs/homarr:latest";
    dashboardPortMapped = assay.eq container.ports ["7575:7575"];
    keepsEncryptionKeyConfigured = assay.eq
      (container.environment ? "SECRET_ENCRYPTION_KEY")
      true;
    firewallOpensDashboard = assay.eq
      (builtins.elem 7575 mod.networking.firewall.allowedTCPPorts)
      true;
    persistentDataDir = assay.eq
      (builtins.match ".*d /data/services/homarr/data .*" rules != null)
      true;
    persistentAppdataDir = assay.eq
      (builtins.match ".*d /data/services/homarr/appdata .*" rules != null)
      true;
    # No native systemd services may exist: the dashboard must stay
    # container-based (this is what failed with `npm start` before).
    noNativeServiceDefinitions = assay.eq
      (builtins.attrNames (mod.systemd.services or {}))
      [];
  }
