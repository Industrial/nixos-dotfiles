# Jackett provides API/torznab support for your torrent trackers. Port = 9117.
{pkgs, ...}: let
  name = "jackett";
  directoryPath = "/data/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      jackett
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Jackett Indexer Proxy";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          # --NoUpdates: nixpkgs owns upgrades; --DataFolder keeps all state
          # (ServerConfig.json + per-indexer JSONs) on the NFS service volume.
          ExecStart = "${pkgs.jackett}/bin/Jackett --NoUpdates --Port 9117 --DataFolder ${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
      ];
    };
  };

  users = {
    users = {
      "${name}" = {
        isSystemUser = true;
        home = "/home/${name}";
        createHome = true;
        group = "${name}";
        extraGroups = ["data"];
      };
    };
    groups = {
      "${name}" = {};
    };
  };
}
