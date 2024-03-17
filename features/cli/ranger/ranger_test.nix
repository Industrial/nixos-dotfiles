let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "ranger_test";
    actual = builtins.elem pkgs.ranger feature.environment.systemPackages;
    expected = true;
  }
]
