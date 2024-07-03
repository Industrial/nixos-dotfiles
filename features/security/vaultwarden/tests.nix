let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "vaultwarden_test";
    actual = feature.services.vaultwarden.enable;
    expected = true;
  }
  {
    name = "vaultwarden_test";
    actual = feature.services.vaultwarden.config.ROCKET_ADDRESS;
    expected = "127.0.0.1";
  }
  {
    name = "vaultwarden_test";
    actual = feature.services.vaultwarden.config.ROCKET_PORT;
    expected = 7000;
  }
  {
    name = "vaultwarden_test";
    actual = feature.services.vaultwarden.config.DOMAIN;
    expected = "http://localhost";
  }
  {
    name = "vaultwarden_test";
    actual = feature.services.vaultwarden.config.SIGNUPS_ALLOWED;
    expected = false;
  }
]
