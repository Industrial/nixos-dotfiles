let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "lxqt-qps_test";
    actual = builtins.elem pkgs.lxqt.qps feature.environment.systemPackages;
    expected = true;
  }
]
