# Lidarr is a music collection manager for Usenet and BitTorrent users, port = 8686.
{pkgs, ...}: let
  directoryPath = "/mnt/well/services/lidarr";
in {
  environment = {
    systemPackages = with pkgs; [
      lidarr
    ];
  };

  systemd = {
    services = {
      lidarr = {
        description = "Lidarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "lidarr";
          Group = "data";
          ExecStart = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 lidarr data - -"
        "d ${directoryPath}/data 0770 lidarr data - -"
      ];
    };
  };

  users = {
    users = {
      lidarr = {
        isSystemUser = true;
        home = "/home/lidarr";
        createHome = true;
        group = "lidarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      lidarr = {};
    };
  };
}
