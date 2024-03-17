let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "fd_test";
    actual = builtins.elem pkgs.fd feature.environment.systemPackages;
    expected = true;
  }
]
