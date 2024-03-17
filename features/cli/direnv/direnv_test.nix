let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "direnv_test";
    actual = builtins.elem pkgs.direnv feature.environment.systemPackages;
    expected = true;
  }
]
