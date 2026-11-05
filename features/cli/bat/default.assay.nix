# Colocated suite: systemPackages and pager session variables from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {bat = "bat";};
  mod = import ./default.nix {inherit pkgs;};
  env = mod.environment.sessionVariables;
in
  assay.suite "bat" {
    systemPackages = assay.eq mod.environment.systemPackages ["bat"];
    manpager = assay.eq env.MANPAGER "bat -l man -p";
    pager = assay.eq env.PAGER "bat -p";
    # "base16" rather than "ansi": both render through the terminal's own palette instead of
    # their own hex, but only base16 addresses colours 16-21, which is where
    # features/window-manager/{alacritty,ghostty} put the six base16 colours ANSI has no slot
    # for. A hex theme name here would mean bat had stopped following the terminal.
    theme = assay.eq env.BAT_THEME "base16";
    themeIsNotHex =
      assay.eq (builtins.match ".*#.*" env.BAT_THEME != null) false;
  }
