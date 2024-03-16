let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.xsession.windowManager.xmonad.enable;
    expected = true;
  }
  {
    actual = feature.xsession.windowManager.xmonad.enableContribAndExtras;
    expected = true;
  }
  {
    actual = feature.xsession.windowManager.xmonad.config;
    expected = ./xmonad.hs;
  }
  {
    actual = feature.xsession.windowManager.xmonad.libFiles.autostart;
    expected = pkgs.writeText "autostart" ''
      #!/usr/bin/env bash
    '';
  }
  {
    actual = feature.home.file.".xinitrc".source;
    expected = ./.xinitrc;
  }
]
