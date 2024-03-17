let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "bitwarden_test";
    actual = builtins.elem pkgs.bitwarden feature.environment.systemPackages;
    expected = true;
  }
]
