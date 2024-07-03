let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "evince_test";
    actual = builtins.elem pkgs.evince feature.environment.systemPackages;
    expected = true;
  }
]
