args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_vaultwarden_enable = {
    expr = feature.services.vaultwarden.enable;
    expected = true;
  };
  test_services_vaultwarden_config_ROCKET_ADDRESS = {
    expr = feature.services.vaultwarden.config.ROCKET_ADDRESS;
    expected = "127.0.0.1";
  };
  test_services_vaultwarden_config_ROCKET_PORT = {
    expr = feature.services.vaultwarden.config.ROCKET_PORT;
    expected = 7000;
  };
  test_services_vaultwarden_config_DOMAIN = {
    expr = feature.services.vaultwarden.config.DOMAIN;
    expected = "http://localhost";
  };
  test_services_vaultwarden_config_SIGNUPS_ALLOWED = {
    expr = feature.services.vaultwarden.config.SIGNUPS_ALLOWED;
    expected = false;
  };
}
