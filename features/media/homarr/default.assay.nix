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
        (r: builtins.match ".*/appdata .*" r != null)
        mod.systemd.tmpfiles.rules)
      true;
    firewallOpensWebPort = assay.eq mod.networking.firewall.allowedTCPPorts [7575];
    syncUnitDeclared = assay.eq
      (mod.systemd.services ? "homarr-sync")
      true;
    syncAfterContainer = assay.eq
      mod.systemd.services."homarr-sync".after
      ["homarr.service"];
    syncIsOneshot = assay.eq
      mod.systemd.services."homarr-sync".serviceConfig.Type
      "oneshot";
    exportTimerHourly = assay.eq
      mod.systemd.services."homarr-export".startAt
      "hourly";
    boardSpecHasProwlarr = assay.eq
      ((builtins.fromJSON (builtins.readFile ./board.json)).integrations)
      [
        {
          name = "Prowlarr";
          kind = "prowlarr";
          url = "http://127.0.0.1:9696";
          secrets = {
            apiKey = "aef3d89a62c5b141289e16adcd63f56aeab40a2ec5f72864b7b3aff203de5e41";
          };
        }
      ];
    boardAppsNamed = assay.eq
      (map (a: a.name) (builtins.fromJSON (builtins.readFile ./board.json)).apps)
      ["Prowlarr" "Sonarr" "Radarr" "Lidarr" "Readarr"];
  }
