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
  # base16 gruvbox dark hard (pair with: caelestia scheme set -n gruvbox -f hard -m dark)
  #
  # The slug is named once, in ./palette.nix, which also carries the sixteen colours as a
  # projection of this exact scheme's upstream YAML. Everything in the terminal stack that
  # needs a hex value reads that file; stylix's own targets read the YAML below. Restating
  # the slug here would let the two describe different schemes.
  palette = import ./palette.nix;
  theme = palette.scheme.slug;

  # Named once and used twice: as stylix's own monospace family, and as fontconfig's generic
  # `monospace` alias below. alacritty.toml and ghostty's config carry the same literal a
  # third and fourth time, which ghostty/default.assay.nix asserts by reading it back out of
  # this file.
  monospaceName = "IosevkaTerm Nerd Font Mono";
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
      # `name` and `package` have to describe the same font, and they did not: the name is
      # an Iosevka Term family while the package was `pkgs.terminus-nerdfont` -- Terminess,
      # a different typeface, and since 2025-10-27 a *throwing* renamed alias
      # (-> nerd-fonts.terminess-ttf). It only ever evaluated because nothing forced it:
      # `stylix.fonts.packages` is [] and the font-packages target inherits only `packages`,
      # so the attribute sat unevaluated. Anything that touched it broke every host at once.
      #
      # nerd-fonts.iosevka-term is the package that actually ships the requested family --
      # `fc-list : family` reports "IosevkaTerm Nerd Font Mono" from it -- and it is already
      # installed fleet-wide by features/nixos/fonts. Naming it here costs no closure and
      # makes the attribute safe to force.
      monospace = {
        name = monospaceName;
        package = pkgs.nerd-fonts.iosevka-term;
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
    polarity = palette.scheme.variant;
  };

  # stylix's `fonts` options reach its own targets, but its fontconfig target is one of the
  # home-manager-only ones -- with no home-manager in this repo, nothing was writing
  # fontconfig's generic `monospace` alias from them. features/window-manager/gnome used to
  # write it, to a fourth font, so removing that left the nixpkgs default (DejaVu Sans Mono)
  # rather than the family above. So the feature that declares the family also declares the
  # alias, and is its single writer.
  #
  # Only `monospace`: serif/sansSerif/emoji are still gnome's, deliberately (see that file).
  # Writing them here too would not override gnome's definitions, it would merge with them
  # into a two-element preference list.
  fonts.fontconfig.defaultFonts.monospace = [monospaceName];
}
