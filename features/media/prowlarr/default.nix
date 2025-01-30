# Prowlarr is a software that allows you to manage multiple indexers for your torrent client. Port = 9696.
{pkgs, ...}: let
  directoryPath = "/mnt/well/services/prowlarr";
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
          ExecStart = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 prowlarr data - -"
        "d ${directoryPath}/data 0770 prowlarr data - -"
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
