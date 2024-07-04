args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_fonts_packages = {
    expr = builtins.elem pkgs.nerdfonts feature.fonts.packages;
    expected = true;
  };
}
