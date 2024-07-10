args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in
  {
    # test_programs_gnupg_agent_pinentryPackage = {
    #   expr = feature.programs.gnupg.agent.pinentryPackage;
    #   expected = pkgs.pinentry-qt;
    # };
    test_security_pam_services_lightdm_enableGnomeKeyring = {
      expr = feature.security.pam.services.lightdm.enableGnomeKeyring;
      expected = true;
    };
    test_services_gnome_gnome-keyring_enable = {
      expr = feature.services.gnome.gnome-keyring.enable;
      expected = true;
    };
    test_services_xserver_desktopManager_xfce_enable = {
      expr = feature.services.xserver.desktopManager.xfce.enable;
      expected = true;
    };
  }
  // builtins.listToAttrs (map (pkg: {
      name = "test_${pkg.name}_in_systemPackages";
      value = {
        expr = builtins.elem pkg feature.environment.systemPackages;
        expected = true;
      };
    })
    (with pkgs; [
      wmctrl
      xarchiver
      xfce.exo
      xfce.garcon
      xfce.libxfce4ui
      xfce.libxfce4util
      xfce.mousepad
      xfce.thunar
      xfce.thunar-archive-plugin
      xfce.xfce4-battery-plugin
      xfce.xfce4-datetime-plugin
      xfce.xfce4-icon-theme
      xfce.xfce4-notifyd
      xfce.xfce4-panel
      xfce.xfce4-panel-profiles
      xfce.xfce4-power-manager
      xfce.xfce4-pulseaudio-plugin
      xfce.xfce4-screensaver
      xfce.xfce4-screenshooter
      xfce.xfce4-session
      xfce.xfce4-settings
      xfce.xfce4-taskmanager
      xfce.xfce4-terminal
      xfce.xfce4-volumed-pulse
      xfce.xfce4-whiskermenu-plugin
      xfce.xfconf
      xfce.xfdashboard
      xfce.xfdesktop
      xfce.xfwm4
      xfce.xfwm4-themes
      xorg.xwininfo
    ]))
