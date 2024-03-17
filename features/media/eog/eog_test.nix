let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "eog_test";
    actual = builtins.elem pkgs.gnome.eog feature.environment.systemPackages;
    expected = true;
  }
]
