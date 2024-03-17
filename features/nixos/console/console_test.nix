let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "console_test";
    actual = feature.console.font;
    expected = "Lat2-Terminus16";
  }
  {
    name = "console_test";
    actual = feature.console.keyMap;
    expected = "us";
  }
]
