let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "appimage-run_test";
    actual = builtins.elem pkgs.appimage-run feature.environment.systemPackages;
    expected = true;
  }
]
