args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  test_networking_networkmanager_enable = {
    expr = feature.networking.networkmanager.enable;
    expected = true;
  };
  test_networking_hostName = {
    expr = feature.networking.hostName;
    expected = settings.hostname;
  };
}
