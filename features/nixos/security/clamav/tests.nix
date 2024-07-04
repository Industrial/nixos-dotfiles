args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_clamav_daemon_enable = {
    expr = feature.services.clamav.daemon.enable;
    expected = true;
  };
  test_services_clamav_updater_enable = {
    expr = feature.services.clamav.updater.enable;
    expected = true;
  };
  test_services_clamav_scanner_enable = {
    expr = feature.services.clamav.scanner.enable;
    expected = true;
  };
  test_services_clamav_scanner_interval = {
    expr = feature.services.clamav.scanner.interval;
    expected = "Weekly Sunday 12:00:00";
  };
}
