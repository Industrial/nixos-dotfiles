# Plex is a media server
{pkgs, ...}: {
  services = {
    plex = {
      enable = true;
      dataDir = "/run/media/tom/Data/Videos";
      openFirewall = true;
      group = "data";
      user = "plex";
    };
  };

  users = {
    users = {
      plex = {
        isSystemUser = false;
        home = "/home/plex";
        createHome = false;
        group = "plex";
        extraGroups = ["data"];
      };
    };

    groups = {
      plex = {};
    };
  };
}
