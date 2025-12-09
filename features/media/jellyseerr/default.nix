# Jellyseerr is a media request management system for Jellyfin, Plex, and Emby. Port = 5055.
{pkgs, ...}: let
  name = "jellyseerr";
  directoryPath = "/mnt/well/services/${name}";
in {
  services = {
    jellyseerr = {
      enable = true;
      port = 5055;
      openFirewall = false; # Set to true if you want to open the firewall port
      package = pkgs.jellyseerr;
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
