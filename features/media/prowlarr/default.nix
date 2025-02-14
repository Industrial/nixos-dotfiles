# Prowlarr is a software that allows you to manage multiple indexers for your torrent client. Port = 9696.
{pkgs, ...}: let
  name = "prowlarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      prowlarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Prowlarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
        "d ${directoryPath}/data 0770 ${name} data - -"
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
