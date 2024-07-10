# Sonarr is a software that helps you find, download and organize your TV shows.
{pkgs, ...}: let
  port = 8989;
in {
  environment = {
    systemPackages = with pkgs; [
      sonarr
    ];
  };

  systemd = {
    services = {
      sonarr = {
        description = "Sonarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "sonarr";
          Group = "data";
          ExecStart = "${pkgs.sonarr}/bin/NzbDrone --nobrowser --data=/data/sonarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/sonarr 0770 sonarr data - -"
        "d /data/sonarr/data 0770 sonarr data - -"
      ];
    };
  };

  users = {
    users = {
      sonarr = {
        isSystemUser = true;
        home = "/home/sonarr";
        createHome = true;
        group = "sonarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      sonarr = {};
    };
  };
}
