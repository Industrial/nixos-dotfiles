{
  settings,
  lib,
  ...
}: {
  networking = {
    hostName = settings.hostname;
    networkmanager = {
      enable = true;
      dns = lib.mkDefault "none";
    };
  };
}
