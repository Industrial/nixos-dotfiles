let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.networking.networkmanager.enable;
    expected = true;
  }
  {
    actual = feature.networking.hostName;
    expected = settings.hostname;
  }
]
