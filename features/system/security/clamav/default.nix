{
  settings,
  pkgs,
  ...
}: {
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;
  services.clamav.scanner.enable = true;
  services.clamav.scanner.interval = "*-*-* 12:00:00";
}
