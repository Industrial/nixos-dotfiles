let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "lxqt-screengrab_test";
    actual = builtins.elem pkgs.lxqt.screengrab feature.environment.systemPackages;
    expected = true;
  }
]
