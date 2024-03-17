let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "bat_test";
    actual = builtins.elem pkgs.bat feature.environment.systemPackages;
    expected = true;
  }
]
