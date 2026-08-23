# Colocated suite: homarr oci-container definition with stubbed args.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {pkgs = {};};
  cfg = mod.virtualisation.oci-containers.containers.homarr;
in
  assay.suite "homarr" {
    usesOfficialImage = assay.eq cfg.image "ghcr.io/homarr-labs/homarr:latest";
    exposesWebUi = assay.eq cfg.ports ["7575:7575"];
    persistsAppdata = assay.eq
      (builtins.any (v: builtins.match ".*/appdata" v != null) cfg.volumes)
      true;
    hasEncryptionKey = assay.eq
      (cfg.environment ? "SECRET_ENCRYPTION_KEY")
      true;
    firewallOpensPort = assay.eq mod.networking.firewall.allowedTCPPorts [7575];
  }
