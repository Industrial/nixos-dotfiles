let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "unzip_test";
    actual = builtins.elem pkgs.unzip feature.environment.systemPackages;
    expected = true;
  }
]
