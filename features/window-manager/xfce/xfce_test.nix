let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "xfce_test: thunar";
    actual = builtins.elem pkgs.xfce.thunar feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "xfce_test: python3Full";
    actual = builtins.elem pkgs.python3Full feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "xfce_test: wmctrl";
    actual = builtins.elem pkgs.wmctrl feature.environment.systemPackages;
    expected = true;
  }
  # TODO: all packages
]
