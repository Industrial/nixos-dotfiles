args @ {pkgs, ...}: let
  feature = import ./default.nix (args
    // {
      inherit pkgs;
      lib = pkgs.lib;
    });
  tinted-theming-schemes =
    (import ./derivations/tinted-theming-schemes.nix {
      inherit pkgs;
      lib = pkgs.lib;
    })
    .tinted-theming-schemes;
in {
  test_stylix_autoEnable = {
    expr = feature.stylix.autoEnable;
    expected = true;
  };
  test_stylix_base16Scheme = {
    expr = feature.stylix.base16Scheme;
    expected = "${tinted-theming-schemes}/share/schemes/atelier-estuary.yaml";
  };
  test_stylix_fonts_emoji_name = {
    expr = feature.stylix.fonts.emoji.name;
    expected = "Noto Color Emoji";
  };
  test_stylix_fonts_emoji_package = {
    expr = feature.stylix.fonts.emoji.package;
    expected = pkgs.noto-fonts-emoji;
  };
  test_stylix_fonts_monospace_name = {
    expr = feature.stylix.fonts.monospace.name;
    expected = "IosevkaTerm Nerd Font Mono";
  };
  test_stylix_fonts_monospace_package = {
    expr = feature.stylix.fonts.monospace.package;
    expected = pkgs.nerdfonts;
  };
  test_stylix_fonts_sansSerif_name = {
    expr = feature.stylix.fonts.sansSerif.name;
    expected = "DejaVu Sans";
  };
  test_stylix_fonts_sansSerif_package = {
    expr = feature.stylix.fonts.sansSerif.package;
    expected = pkgs.dejavu_fonts;
  };
  test_stylix_fonts_serif_name = {
    expr = feature.stylix.fonts.serif.name;
    expected = "DejaVu Serif";
  };
  test_stylix_fonts_serif_package = {
    expr = feature.stylix.fonts.serif.package;
    expected = pkgs.dejavu_fonts;
  };
  test_stylix_image = {
    expr = feature.stylix.image;
    expected = ./wallpaper.jpg;
  };
  test_stylix_polarity = {
    expr = feature.stylix.polarity;
    expected = "dark";
  };
}
