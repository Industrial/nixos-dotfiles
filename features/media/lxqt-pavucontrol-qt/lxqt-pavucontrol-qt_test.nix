let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "lxqt-pavucontrol-qt_test";
    actual = builtins.elem pkgs.lxqt.pavucontrol-qt feature.environment.systemPackages;
    expected = true;
  }
]
