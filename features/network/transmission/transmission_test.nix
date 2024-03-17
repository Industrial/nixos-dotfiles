let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "transmission_test";
    actual = builtins.elem pkgs.transmission-gtk feature.environment.systemPackages;
    expected = true;
  }
]
