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
        isSystemUser = true;
        home = "/home/plex";
        createHome = true;
        group = "data";
        extraGroups = ["data"];
      };
    };
    groups = {
      plex = {};
    };
  };
}
