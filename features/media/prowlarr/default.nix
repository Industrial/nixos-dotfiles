# Prowlarr is a software that allows you to manage multiple indexers for your torrent client.
{pkgs, ...}: let
  port = 9696;
in {
  environment = {
    systemPackages = with pkgs; [
      prowlarr
    ];
  };

  systemd = {
    services = {
      prowlarr = {
        description = "Prowlarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "prowlarr";
          Group = "data";
          ExecStart = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data=/data/prowlarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/prowlarr 0770 prowlarr data - -"
        "d /data/prowlarr/data 0770 prowlarr data - -"
      ];
    };
  };

  users = {
    users = {
      prowlarr = {
        isSystemUser = true;
        home = "/home/prowlarr";
        createHome = true;
        group = "prowlarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      prowlarr = {};
    };
  };
}
