# Radarr is a movie collection manager for Usenet and BitTorrent users. Port = 7878.
{pkgs, ...}: let
  directoryPath = "/mnt/well/services/radarr";
in {
  environment = {
    systemPackages = with pkgs; [
      radarr
    ];
  };

  systemd = {
    services = {
      radarr = {
        description = "Radarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "radarr";
          Group = "data";
          ExecStart = "${pkgs.radarr}/bin/Radarr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 radarr data - -"
        "d ${directoryPath}/data 0770 radarr data - -"
      ];
    };
  };

  users = {
    users = {
      radarr = {
        isSystemUser = true;
        home = "/home/radarr";
        createHome = true;
        group = "radarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      radarr = {};
    };
  };
}
