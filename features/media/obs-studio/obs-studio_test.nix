let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "obs-studio_test";
    actual = builtins.elem pkgs.obs-studio feature.environment.systemPackages;
    expected = true;
  }
]
