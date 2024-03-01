{
  settings,
  pkgs,
  lib,
  fetchFromGitHub,
  ...
}: let
  tinted-theming-schemes = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "tinted-theming-schemes";
    version = "spec-0.11";

    src = pkgs.fetchFromGitHub {
      owner = "tinted-theming";
      repo = "schemes";
      rev = "395074124283df993571f2abb9c713f413b76e6e";
      sha256 = "sha256-9LmwYbtTxNFiP+osqRUbOXghJXpYvyvAwBwW80JMO7s=";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/schemes/
      install base16/*.yaml $out/share/schemes/

      runHook postInstall
    '';

    meta = with lib; {
      description = "All the color schemes for use in base16 packages";
      homepage = finalAttrs.src.meta.homepage;
      maintainers = [maintainers.DamienCassou];
      license = licenses.mit;
    };
  });
in {
  home.packages = with pkgs; [
    tinted-theming-schemes
  ];

  stylix.autoEnable = true;
  stylix.base16Scheme = "${tinted-theming-schemes}/share/schemes/equilibrium-gray-dark.yaml";
  stylix.fonts.emoji.name = "Noto Color Emoji";
  stylix.fonts.emoji.package = pkgs.noto-fonts-emoji;
  stylix.fonts.monospace.name = "Fira Code";
  stylix.fonts.monospace.package = pkgs.nerdfonts;
  stylix.fonts.sansSerif.name = "DejaVu Sans";
  stylix.fonts.sansSerif.package = pkgs.dejavu_fonts;
  stylix.fonts.serif.name = "DejaVu Serif";
  stylix.fonts.serif.package = pkgs.dejavu_fonts;
  stylix.image = ./wallpaper.jpg;
  stylix.polarity = "dark";
  stylix.targets.vscode.enable = true;
}
