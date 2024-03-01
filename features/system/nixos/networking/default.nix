{
  pkgs,
  settings,
  ...
}: {
  networking.networkmanager.enable = true;
  networking.hostName = settings.hostname;
}
