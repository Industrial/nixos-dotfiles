# xmonad is a tiling window manager for X. It is written in Haskell, and is
# extensible in that language.
{
  settings,
  pkgs,
  ...
}: {
  xsession.windowManager.xmonad.enable = true;
  xsession.windowManager.xmonad.enableContribAndExtras = true;
  xsession.windowManager.xmonad.config = ./xmonad.hs;
  # xsession.windowManager.xmonad.extraPackages = [];
  xsession.windowManager.xmonad.libFiles = {
    "autostart" = pkgs.writeText "autostart" ''
      #!/usr/bin/env bash
    '';
  };
  home.file.".xinitrc".source = ./.xinitrc;
}
