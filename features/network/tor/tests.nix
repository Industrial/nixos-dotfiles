args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_tor_enable = {
    expr = feature.services.tor.enable;
    expected = true;
  };
  test_services_tor_client_enable = {
    expr = feature.services.tor.client.enable;
    expected = true;
  };
  test_services_tor_relay_enable = {
    expr = feature.services.tor.relay.enable;
    expected = false;
  };
}
