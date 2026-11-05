# Alacritty, the default terminal emulator (SUPER+Return).
#
# The colours are APPENDED to the hand-written alacritty.toml rather than written into it.
# That keeps one hex literal in the repo -- features/window-manager/stylix/palette.nix -- and
# it keeps the committed .toml free of colour, which is what its sibling suite and ghostty's
# assert. The file on disk is the concatenation; the file in git is still just window, font
# and presentation.
#
# Why this matters beyond Alacritty: slots 0-15 here are the ANSI palette that *every*
# terminal program inherits. A `bold red` in starship.toml, bat's `base16` theme, fzf's
# default chrome, delta's diff markers and btop's meters all resolve through these sixteen
# values, so setting them is what makes one scheme reach the whole stack instead of nine
# apps each needing their own theme file.
{
  settings,
  pkgs,
  ...
}: let
  palette = import ./../stylix/palette.nix;

  colorAt = i: builtins.elemAt palette.ansi i;

  # tinted-theming/tinted-alacritty's mapping. `dim` is deliberately not emitted: Alacritty
  # derives it from `normal` when absent, and base16 specifies no dim range.
  namedBlock = name: offset: ''

    [colors.${name}]
    black = "${colorAt (offset + 0)}"
    red = "${colorAt (offset + 1)}"
    green = "${colorAt (offset + 2)}"
    yellow = "${colorAt (offset + 3)}"
    blue = "${colorAt (offset + 4)}"
    magenta = "${colorAt (offset + 5)}"
    cyan = "${colorAt (offset + 6)}"
    white = "${colorAt (offset + 7)}"
  '';

  # ANSI has no slot for base09/base0F or the four extra greys, so base16 parks them at
  # 16-21. Programs that know the convention (bat's base16 theme among them) read them there.
  indexedBlock = builtins.concatStringsSep "" (map (i: ''

    [[colors.indexed_colors]]
    index = ${toString i}
    color = "${colorAt i}"
  '') [16 17 18 19 20 21]);

  colorsToml =
    ''

      # --- generated from features/window-manager/stylix/palette.nix; do not hand-edit ---

      [colors.primary]
      background = "${palette.withHash.base00}"
      foreground = "${palette.withHash.base05}"
      dim_foreground = "${palette.withHash.base04}"
      bright_foreground = "${palette.withHash.base06}"

      [colors.cursor]
      text = "${palette.withHash.base00}"
      cursor = "${palette.withHash.base05}"

      [colors.vi_mode_cursor]
      text = "${palette.withHash.base00}"
      cursor = "${palette.withHash.base0C}"

      [colors.selection]
      text = "${palette.withHash.base05}"
      background = "${palette.withHash.base02}"
    ''
    + namedBlock "normal" 0
    + namedBlock "bright" 8
    + indexedBlock;

  alacrittyToml = pkgs.writeTextFile {
    name = "alacritty.toml";
    text = builtins.readFile ./.config/alacritty/alacritty.toml + colorsToml;
  };
in {
  environment.systemPackages = with pkgs; [
    alacritty
  ];

  system.activationScripts.linkFile = {
    text = ''
      mkdir -p /home/${settings.username}/.config/alacritty
      ln -sf ${alacrittyToml} /home/${settings.username}/.config/alacritty/alacritty.toml
    '';
  };
}
