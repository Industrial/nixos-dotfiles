let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "fonts_test";
    actual = builtins.elem pkgs.nerdfonts feature.fonts.packages;
    expected = true;
  }
]
