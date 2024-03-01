{
  settings,
  pkgs,
  ...
}: {
  users.users.${settings.username} = {
    isNormalUser = true;
    home = settings.userdir;
    description = settings.userfullname;
    extraGroups = [
      "audio"
      "networkmanager"
      "plugdev"
      "wheel"
    ];
  };
}
