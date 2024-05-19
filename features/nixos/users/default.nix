{settings, ...}: {
  nix.settings.trusted-users = ["root" "${settings.username}"];
  users.groups.data = {
    gid = 1111;
    members = ["${settings.username}"];
  };
  users.users.${settings.username} = {
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
}
