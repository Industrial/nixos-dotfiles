let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.console.font;
    expected = "Lat2-Terminus16";
  }
  {
    actual = feature.console.keyMap;
    expected = "us";
  }
]
