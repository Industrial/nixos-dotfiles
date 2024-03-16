let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.xfce.thunar feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.python3Full feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.wmctrl feature.environment.systemPackages;
    expected = true;
  }
  # TODO: all packages
]
