{
  settings,
  pkgs,
  ...
}: {
  services.invidious.enable = true;
  services.invidious.port = 4000;
}
