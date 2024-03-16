let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "p7zip_test";
    actual = builtins.elem pkgs.p7zip feature.environment.systemPackages;
    expected = true;
  }
]
