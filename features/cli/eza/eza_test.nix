let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "eza_test";
    actual = builtins.elem pkgs.eza feature.environment.systemPackages;
    expected = true;
  }
]
