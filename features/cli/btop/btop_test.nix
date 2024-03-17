let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "btop_test";
    actual = builtins.elem pkgs.btop feature.environment.systemPackages;
    expected = true;
  }
]
