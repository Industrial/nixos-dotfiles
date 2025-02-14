# Readarr is a movie collection manager for Usenet and BitTorrent users. Port = 7878.
{pkgs, ...}: let
  name = "readarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      readarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Readarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.readarr}/bin/Readarr --nobrowser --data=${directoryPath}";
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
