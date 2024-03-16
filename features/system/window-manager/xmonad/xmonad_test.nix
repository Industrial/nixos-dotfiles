let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "xmonad_test";
    actual = feature.xsession.windowManager.xmonad.enable;
    expected = true;
  }
  {
    name = "xmonad_test";
    actual = feature.xsession.windowManager.xmonad.enableContribAndExtras;
    expected = true;
  }
  {
    name = "xmonad_test";
    actual = feature.xsession.windowManager.xmonad.config;
    expected = ./xmonad.hs;
  }
  {
    name = "xmonad_test";
    actual = feature.xsession.windowManager.xmonad.libFiles.autostart;
    expected = pkgs.writeText "autostart" ''
      #!/usr/bin/env bash
    '';
  }
  {
    name = "xmonad_test";
    actual = feature.home.file.".xinitrc".source;
    expected = ./.xinitrc;
  }
]
