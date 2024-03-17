let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "starship_test";
    actual = builtins.elem pkgs.starship feature.environment.systemPackages;
    expected = true;
  }
]
