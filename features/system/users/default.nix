{pkgs, c9config, ...}: {
  users.users.tom.isNormalUser = true;
  users.users.tom.home = "/home/${c9config.username}";
  users.users.tom.description = c9config.userfullname;
  users.users.tom.extraGroups = [
    "audio"
    "networkmanager"
    "plugdev"
    "wheel"
  ];
}
