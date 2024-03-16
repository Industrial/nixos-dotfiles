let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "fish_test";
    actual = builtins.elem pkgs.fishPlugins.bass feature.environment.systemPackages;
    expected = true;
  }
  # TODO: Test everything
]
