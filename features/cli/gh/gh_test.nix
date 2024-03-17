let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "gh_test";
    actual = builtins.elem pkgs.gh feature.environment.systemPackages;
    expected = true;
  }
]
