# TODO: Test everything.
let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.zellij feature.environment.systemPackages;
    expected = true;
  }
]
