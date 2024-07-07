{
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
  # equilibrium-gray-dark.yaml

  stylix = {
    autoEnable = true;
    base16Scheme = "${tinted-theming-schemes}/share/schemes/atelier-estuary.yaml";
    fonts = {
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-emoji;
      };
      monospace = {
        name = "IosevkaTerm Nerd Font Mono";
        package = pkgs.nerdfonts;
      };
      sansSerif = {
        name = "DejaVu Sans";
        package = pkgs.dejavu_fonts;
      };
      serif = {
        name = "DejaVu Serif";
        package = pkgs.dejavu_fonts;
      };
    };
    image = ./wallpaper.jpg;
    polarity = "dark";
  };
}
