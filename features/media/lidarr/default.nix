# Lidarr is a music collection manager for Usenet and BitTorrent users, port = 8686.
{pkgs, ...}: let
  name = "lidarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      lidarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Lidarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data=${directoryPath}";
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
