# Overseerr is a request management and media discovery tool for Plex, Sonarr, and Radarr. Port = 5055.
{pkgs, ...}: let
  name = "overseerr";
  directoryPath = "/mnt/well/services/${name}";
in {
  services = {
    overseerr = {
      enable = true;
      package = pkgs.overseerr;
    };
  };

  systemd = {
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
