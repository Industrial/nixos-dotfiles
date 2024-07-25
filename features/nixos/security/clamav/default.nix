{...}: {
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;
  services.clamav.scanner.enable = true;
  services.clamav.scanner.interval = "Weekly Sunday 12:00:00";
}
