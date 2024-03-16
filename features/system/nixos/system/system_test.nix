let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "system_test";
    actual = feature.programs.dconf.enable;
    expected = true;
  }
]
