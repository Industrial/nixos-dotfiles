{settings, ...}: {
  nix = {
    settings = {
      trusted-users = ["root" "${settings.username}"];
    };
  };

  users = {
    groups = {
      data = {
        gid = 1111;
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
      ];
    };
  };
}
