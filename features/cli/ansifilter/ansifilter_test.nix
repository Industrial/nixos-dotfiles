let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "ansifilter_test";
    actual = builtins.elem pkgs.ansifilter feature.environment.systemPackages;
    expected = true;
  }
]
