let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.vaultwarden.enable;
    expected = true;
  }
  {
    actual = feature.services.vaultwarden.config.ROCKET_ADDRESS;
    expected = "127.0.0.1";
  }
  {
    actual = feature.services.vaultwarden.config.ROCKET_PORT;
    expected = 7000;
  }
  {
    actual = feature.services.vaultwarden.config.DOMAIN;
    expected = "http://localhost";
  }
  {
    actual = feature.services.vaultwarden.config.SIGNUPS_ALLOWED;
    expected = false;
  }
]
