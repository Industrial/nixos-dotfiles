let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "okular_test";
    actual = builtins.elem pkgs.okular feature.environment.systemPackages;
    expected = true;
  }
]
