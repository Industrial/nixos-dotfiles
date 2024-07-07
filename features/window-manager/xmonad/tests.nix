args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_xsession_windowManager_xmonad_enable = {
    expr = feature.xsession.windowManager.xmonad.enable;
    expected = true;
  };
  test_xsession_windowManager_xmonad_enableContribAndExtras = {
    expr = feature.xsession.windowManager.xmonad.enableContribAndExtras;
    expected = true;
  };
  test_xsession_windowManager_xmonad_config = {
    expr = feature.xsession.windowManager.xmonad.config;
    expected = ./xmonad.hs;
  };
  test_xsession_windowManager_xmonad_libFiles_autostart = {
    expr = feature.xsession.windowManager.xmonad.libFiles.autostart;
    expected = pkgs.writeText "autostart" ''
      #!/usr/bin/env bash
    '';
  };
  test_home_file_xinitrc_source = {
    expr = feature.home.file.".xinitrc".source;
    expected = ./.xinitrc;
  };
}
