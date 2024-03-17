let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "meld_test";
    actual = builtins.elem pkgs.meld feature.environment.systemPackages;
    expected = true;
  }
]
