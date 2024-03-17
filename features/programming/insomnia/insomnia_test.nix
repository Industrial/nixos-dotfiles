let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "insomnia_test";
    actual = builtins.elem pkgs.insomnia feature.environment.systemPackages;
    expected = true;
  }
]
