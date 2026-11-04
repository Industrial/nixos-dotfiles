# Bat is a replacement for Cat, and the pager for man pages and generic output.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      bat
    ];
    sessionVariables = {
      MANPAGER = "bat -l man -p";
      PAGER = "bat -p";
      # "ansi" keeps bat on the terminal's own 16 colours; stylix owns the palette.
      BAT_THEME = "ansi";
    };
  };
}
