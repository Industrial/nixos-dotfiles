# Sonarr is a software that helps you find, download and organize your TV shows. Port = 8989.
{pkgs, ...}: let
  name = "sonarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      sonarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Sonarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.sonarr}/bin/NzbDrone --nobrowser --data=${directoryPath}";
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
