{settings, ...}: {
  nix = {
    settings = {
      allowed-users = ["@wheel"];
      trusted-users = ["root" "${settings.username}"];
    };
  };

  users = {
    groups = {
      data = {
        gid = 1111;
        members = ["${settings.username}"];
      };
      games = {
        gid = 1112;
        members = ["${settings.username}"];
      };
    };

    users = {
      "${settings.username}" = {
        isNormalUser = true;
        home = settings.userdir;
        description = settings.userfullname;
        extraGroups = [
          "audio"
          "networkmanager"
          "plugdev"
          "wheel"
          "data"
          "games"
        ];
      };
    };
  };

  systemd = {
    tmpfiles = {
      rules = [
        # This creates a directory owned by root and with the group set to data
        # that is readable and writable by the members of the data group.
        "d /data 0770 root data - -"

        # This creates a directory owned by root and with the group set to games
        # that is readable and writable by the members of the games group.
        "d /games 0770 root games - -"
      ];
    };
  };
}
