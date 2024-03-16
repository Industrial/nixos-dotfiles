let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "nix-unit_test";
    actual = builtins.elem pkgs.nix-unit feature.environment.systemPackages;
    expected = true;
  }
]
