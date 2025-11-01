{
  pkgs,
  lib,
  ...
}: let
  tinted-theming-schemes = (import ./derivations/tinted-theming-schemes.nix {inherit pkgs lib;}).tinted-theming-schemes;

  # atelier-cave
  # atelier-estuary
  # atelier-plateau
  # equilibrium-gray-dark.yaml
  theme = "equilibrium-gray-dark";
in {
  environment.systemPackages = with pkgs; [
    tinted-theming-schemes
  ];

  stylix = {
    autoEnable = true;
    base16Scheme = "${tinted-theming-schemes}/share/schemes/${theme}.yaml";
    fonts = {
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-color-emoji;
      };
      monospace = {
        name = "IosevkaTerm Nerd Font Mono";
        # package = pkgs.nerdfonts;
        package = pkgs.terminus-nerdfont;
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
