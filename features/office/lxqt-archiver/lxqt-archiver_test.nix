let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "lxqt-archiver_test";
    actual = builtins.elem pkgs.lxqt.lxqt-archiver feature.environment.systemPackages;
    expected = true;
  }
]
