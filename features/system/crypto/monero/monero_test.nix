let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "monero_test";
    actual = builtins.elem pkgs.monero feature.environment.systemPackages;
    expected = true;
  }
]
