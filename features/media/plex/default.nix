# Plex is a media server
{pkgs, ...}: let
  user = "plex";
  group = "data";
in {
  services = {
    plex = {
      enable = true;
      dataDir = "/home/${user}/data";
      openFirewall = true;
      inherit user group;
    };
  };

  nix = {
    settings = {
      trusted-users = [user];
    };
  };

  users = {
    users = {
      "${user}" = {
        inherit group;
        isSystemUser = true;
        home = "/home/${user}";
        createHome = true;
        extraGroups = [];
      };
    };
    # groups = {
    #   plex = {};
    # };
  };
}
