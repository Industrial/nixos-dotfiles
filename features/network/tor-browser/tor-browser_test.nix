let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "tor-browser_test";
    actual = builtins.elem pkgs.tor-browser-bundle-bin feature.environment.systemPackages;
    expected = true;
  }
]
