# Plex is a media server
{pkgs, ...}: {
  services = {
    plex = {
      enable = true;
      dataDir = "/run/media/tom/Data/Videos";
      openFirewall = true;
      group = "data";
    };
  };
}
