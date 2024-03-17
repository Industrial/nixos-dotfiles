let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "invidious_test";
    actual = feature.services.invidious.enable;
    expected = true;
  }
  {
    name = "invidious_test";
    actual = feature.services.invidious.port;
    expected = 4000;
  }
]
