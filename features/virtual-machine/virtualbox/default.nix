{
  settings,
  pkgs,
  ...
}: {
  # Don't install virtualbox to systemPackages. It will make it unusable.
  # Instead use the options below.
  virtualisation = {
    virtualbox = {
      host = {
        enable = true;
        enableExtensionPack = true;
      };
      guest = {
        enable = true;
        dragAndDrop = true;
      };
    };
  };
  users = {
    extraGroups = {
      vboxusers = {
        members = [settings.userfullname];
      };
    };
  };
}
