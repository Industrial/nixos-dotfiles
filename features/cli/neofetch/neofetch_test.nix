let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "neofetch_test";
    actual = builtins.elem pkgs.neofetch feature.environment.systemPackages;
    expected = true;
  }
]
