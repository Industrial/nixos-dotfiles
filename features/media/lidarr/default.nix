# Lidarr is a music collection manager for Usenet and BitTorrent users, port = 8686.
{pkgs, ...}: {
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
          ExecStart = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data=/data/lidarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/lidarr 0770 lidarr data - -"
        "d /data/lidarr/data 0770 lidarr data - -"
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
