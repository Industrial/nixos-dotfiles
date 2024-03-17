let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "gparted_test";
    actual = builtins.elem pkgs.gparted feature.environment.systemPackages;
    expected = true;
  }
]
