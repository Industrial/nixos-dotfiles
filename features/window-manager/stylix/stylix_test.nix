let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings lib;};
  tinted-theming-schemes = (import ./derivations/tinted-theming-schemes.nix {inherit pkgs lib;}).tinted-theming-schemes;
in [
  # {
  #   name = "stylix_test";
  #   actual = builtins.elem pkgs.slock feature.environment.systemPackages;
  #   expected = true;
  # }
  {
    name = "stylix_test: stylix.autoEnable";
    actual = feature.stylix.autoEnable;
    expected = true;
  }
  {
    name = "stylix_test: stylix.base16Scheme";
    actual = feature.stylix.base16Scheme;
    expected = "${tinted-theming-schemes}/share/schemes/equilibrium-gray-dark.yaml";
  }
  {
    name = "stylix_test: stylix.fonts.emoji.name";
    actual = feature.stylix.fonts.emoji.name;
    expected = "Noto Color Emoji";
  }
  {
    name = "stylix_test: stylix.fonts.emoji.package";
    actual = feature.stylix.fonts.emoji.package;
    expected = pkgs.noto-fonts-emoji;
  }
  {
    name = "stylix_test: stylix.fonts.monospace.name";
    actual = feature.stylix.fonts.monospace.name;
    expected = "IosevkaTerm Nerd Font Mono";
  }
  {
    name = "stylix_test: stylix.fonts.monospace.package";
    actual = feature.stylix.fonts.monospace.package;
    expected = pkgs.nerdfonts;
  }
  {
    name = "stylix_test: stylix.fonts.sansSerif.name";
    actual = feature.stylix.fonts.sansSerif.name;
    expected = "DejaVu Sans";
  }
  {
    name = "stylix_test: stylix.fonts.sansSerif.package";
    actual = feature.stylix.fonts.sansSerif.package;
    expected = pkgs.dejavu_fonts;
  }
  {
    name = "stylix_test: stylix.fonts.serif.name";
    actual = feature.stylix.fonts.serif.name;
    expected = "DejaVu Serif";
  }
  {
    name = "stylix_test: stylix.fonts.serif.package";
    actual = feature.stylix.fonts.serif.package;
    expected = pkgs.dejavu_fonts;
  }
  {
    name = "stylix_test: stylix.image";
    actual = feature.stylix.image;
    expected = ./wallpaper.jpg;
  }
  {
    name = "stylix_test: stylix.polarity";
    actual = feature.stylix.polarity;
    expected = "dark";
  }
]
