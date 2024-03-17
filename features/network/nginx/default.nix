{
  settings,
  pkgs,
  ...
}: {
  services.nginx.enable = true;
  services.nginx.recommendedGzipSettings = true;
}
