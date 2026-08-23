# Colocated suite: homarr OCI-container module with stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {pkgs = {};};
  ctr = mod.virtualisation.oci-containers.containers."homarr";
in
  assay.suite "homarr" {
    usesOfficialImage = assay.eq ctr.image "ghcr.io/homarr-labs/homarr:latest";
    webPortMapped = assay.eq ctr.ports ["7575:7575"];
    encryptionKeySet = assay.eq (ctr.environment ? "SECRET_ENCRYPTION_KEY") true;
    dataVolume = assay.eq
      (builtins.any (v: builtins.match ".*/data" v != null) ctr.volumes)
      true;
    appdataVolume = assay.eq
      (builtins.any (v: builtins.match ".*/appdata" v != null) ctr.volumes)
      true;
    tmpfilesAppdata = assay.eq
      (builtins.any
        (r: builtins.match ".*${"/data/services/homarr/appdata"} .*" r != null)
        mod.systemd.tmpfiles.rules)
      true;
    firewallOpensWebPort = assay.eq mod.networking.firewall.allowedTCPPorts [7575];
  }
