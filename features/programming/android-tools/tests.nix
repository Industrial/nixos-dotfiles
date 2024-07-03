let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "android-tools_test";
    actual = builtins.elem pkgs.android-tools feature.environment.systemPackages;
    expected = true;
  }
]
