let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.invidious.enable;
    expected = true;
  }
  {
    actual = feature.services.invidious.port;
    expected = 4000;
  }
]
