{
  settings,
  pkgs,
  lib,
  ...
}: let
  tinted-theming-schemes = (import ./derivations/tinted-theming-schemes.nix {inherit pkgs lib;}).tinted-theming-schemes;
in {
  environment.systemPackages = with pkgs; [
    tinted-theming-schemes
  ];

  # atelier-cave
  # atelier-estuary
  # atelier-plateau

  stylix.autoEnable = true;
  stylix.base16Scheme = "${tinted-theming-schemes}/share/schemes/atelier-estuary.yaml";
  stylix.fonts.emoji.name = "Noto Color Emoji";
  stylix.fonts.emoji.package = pkgs.noto-fonts-emoji;
  stylix.fonts.monospace.name = "IosevkaTerm Nerd Font Mono";
  stylix.fonts.monospace.package = pkgs.nerdfonts;
  stylix.fonts.sansSerif.name = "DejaVu Sans";
  stylix.fonts.sansSerif.package = pkgs.dejavu_fonts;
  stylix.fonts.serif.name = "DejaVu Serif";
  stylix.fonts.serif.package = pkgs.dejavu_fonts;
  stylix.image = ./wallpaper.jpg;
  stylix.polarity = "dark";
}
