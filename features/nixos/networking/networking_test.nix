let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "networking_test";
    actual = feature.networking.networkmanager.enable;
    expected = true;
  }
  {
    name = "networking_test";
    actual = feature.networking.hostName;
    expected = settings.hostname;
  }
]
