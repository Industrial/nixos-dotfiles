{
  settings,
  lib,
  ...
}: {
  networking = {
    hostName = settings.hostname;
    networkmanager = {
      enable = true;
    };
  };
}
