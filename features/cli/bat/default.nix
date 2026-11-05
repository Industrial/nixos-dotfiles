# Bat is a replacement for Cat, and the pager for man pages and generic output.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      bat
    ];
    sessionVariables = {
      MANPAGER = "bat -l man -p";
      PAGER = "bat -p";
      # "base16", not "ansi" and not a hex theme file.
      #
      # bat resolves BAT_THEME against themes compiled into the binary, so pointing it at a
      # generated .tmTheme would mean shipping a `bat cache --build` output keyed to this
      # exact bat version -- machinery that rots on every bat bump. Both of bat's built-in
      # terminal-palette themes avoid that, and "base16" is the one that matches the scheme
      # the fleet actually runs: it addresses colours 0-21, i.e. it knows about the six
      # base16 colours that ANSI has no slot for, which features/window-manager/alacritty
      # and features/window-manager/ghostty now emit as indexed colours 16-21. "ansi" only
      # uses the basic eight, so it rendered the same palette with less of it.
      #
      # This also themes delta: `delta.syntax-theme` defaults to $BAT_THEME, so git's pager
      # inherits the scheme from here rather than needing its own copy.
      BAT_THEME = "base16";
    };
  };
}
