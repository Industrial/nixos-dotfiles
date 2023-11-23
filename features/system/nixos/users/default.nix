{pkgs, c9config, ...}: {
  users.users."${c9config.username}".isNormalUser = true;
  users.users."${c9config.username}".home = c9config.userdir;
  users.users."${c9config.username}".description = c9config.userfullname;
  users.users."${c9config.username}".extraGroups = [
    "audio"
    "networkmanager"
    "plugdev"
    "wheel"
  ];
}
