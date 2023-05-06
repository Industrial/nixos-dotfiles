{pkgs, ...}: {
  # Stylix
  stylix.image = ./wallpaper.jpg;
  stylix.polarity = "dark";
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";
  stylix.fonts.serif.package = pkgs.dejavu_fonts;
  stylix.fonts.serif.name = "DejaVu Serif";
  stylix.fonts.sansSerif.package = pkgs.dejavu_fonts;
  stylix.fonts.sansSerif.name = "DejaVu Sans";
  stylix.fonts.monospace.package = pkgs.nerdfonts;
  stylix.fonts.monospace.name = "Fira Code";
  stylix.fonts.emoji.package = pkgs.noto-fonts-emoji;
  stylix.fonts.emoji.name = "Noto Color Emoji";
}
