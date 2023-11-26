{
  pkgs,
  c9config,
  ...
}: {
  users.users.${c9config.username} = {
    isNormalUser = true;
    home = c9config.userdir;
    description = c9config.userfullname;
    extraGroups = [
      "audio"
      "networkmanager"
      "plugdev"
      "wheel"
    ];
  };
}
