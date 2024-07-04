args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_ntpd-rs_enable = {
    expr = feature.services.ntpd-rs.enable;
    expected = true;
  };
  test_services_ntpd-rs_metrics_enable = {
    expr = feature.services.ntpd-rs.metrics.enable;
    expected = true;
  };
}
