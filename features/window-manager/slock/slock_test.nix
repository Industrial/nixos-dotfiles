let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "slock_test";
    actual = builtins.elem pkgs.slock feature.environment.systemPackages;
    expected = true;
  }
]
