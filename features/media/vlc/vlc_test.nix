let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "vlc_test";
    actual = builtins.elem pkgs.vlc feature.environment.systemPackages;
    expected = true;
  }
]
