# Ghostty is a GPU-accelerated terminal emulator. It sits beside Alacritty
# rather than replacing it: Alacritty keeps SUPER+Return, Ghostty answers to
# SUPER+SHIFT+Return, so the fleet can try it without betting the default
# terminal on it.
#
# Colours are APPENDED to the hand-written config.ghostty rather than written into it, the
# same way features/window-manager/alacritty builds its [colors] section. The committed file
# stays free of colour keys and hex literals -- which its own suite asserts, and which is
# still worth asserting: it means nobody can fork the scheme by hand-editing the config, only
# by changing features/window-manager/stylix/palette.nix, where the fleet's one copy of the
# sixteen values lives.
{
  settings,
  pkgs,
  ...
}: let
  palette = import ./../stylix/palette.nix;

  # `palette = N=#rrggbb` is a repeated key; ghostty(5) accumulates it rather than replacing.
  # All 22 slots are emitted: 0-15 is the ANSI palette every terminal program inherits, and
  # 16-21 carries the six base16 colours ANSI has no slot for.
  paletteLines =
    builtins.concatStringsSep "\n"
    (builtins.genList
      (i: "palette = ${toString i}=${builtins.elemAt palette.ansi i}")
      (builtins.length palette.ansi));

  # `theme` is deliberately NOT set. It would load one of ghostty's bundled theme files and
  # that file's own palette would be applied alongside these keys, giving two scheme authors.
  colorConfig = ''

    # --- generated from features/window-manager/stylix/palette.nix; do not hand-edit ---
    background = ${palette.withHash.base00}
    foreground = ${palette.withHash.base05}
    cursor-color = ${palette.withHash.base05}
    cursor-text = ${palette.withHash.base00}
    selection-background = ${palette.withHash.base02}
    selection-foreground = ${palette.withHash.base05}
    split-divider-color = ${palette.withHash.base02}
    unfocused-split-fill = ${palette.withHash.base00}
    ${paletteLines}
  '';

  ghosttyConfig = pkgs.writeTextFile {
    name = "config.ghostty";
    text = builtins.readFile ./.config/ghostty/config.ghostty + colorConfig;
  };
in {
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  # Activation script names share one namespace across every feature, so this
  # one is named for its feature rather than the generic `linkFile`, which
  # features/window-manager/alacritty already defines.
  system.activationScripts.linkGhosttyConfig = {
    text = ''
      mkdir -p ${settings.userdir}/.config/ghostty
      ln -sf ${ghosttyConfig} ${settings.userdir}/.config/ghostty/config.ghostty
    '';
  };
}
