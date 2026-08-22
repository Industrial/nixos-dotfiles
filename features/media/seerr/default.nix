# Seerr is a request management and media discovery tool for Plex, Sonarr, and Radarr. Port = 5055.
{config, lib, pkgs, ...}: let
  name = "seerr";
  directoryPath = "/data/services/${name}";
in {
  services = {
    seerr = {
      enable = true;
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