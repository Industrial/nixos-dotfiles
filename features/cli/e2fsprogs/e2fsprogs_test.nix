let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "e2fsprogs_test";
    actual = builtins.elem pkgs.e2fsprogs feature.environment.systemPackages;
    expected = true;
  }
]
