let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "ripgrep_test";
    actual = builtins.elem pkgs.ripgrep feature.environment.systemPackages;
    expected = true;
  }
]
