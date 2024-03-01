# XFCE Packages.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Required for the movescreen.py script.
    python3Full

    #xfce.xfce4-embed-plugin
    #xfce.xfce4-eyes-plugin
    #xfce.xfce4-i3-workspaces-plugin
    #xfce.xfce4-namebar-plugin
    (pkgs.xfce.thunar.override {thunarPlugins = [pkgs.xfce.thunar-archive-plugin];})
    xfce.libxfce4ui
    xfce.libxfce4util
    xfce.xfce4-appfinder
    xfce.xfce4-battery-plugin
    xfce.xfce4-clipman-plugin
    xfce.xfce4-cpufreq-plugin
    xfce.xfce4-cpugraph-plugin
    xfce.xfce4-datetime-plugin
    xfce.xfce4-dev-tools
    xfce.xfce4-dict
    xfce.xfce4-dockbarx-plugin
    xfce.xfce4-fsguard-plugin
    xfce.xfce4-genmon-plugin
    xfce.xfce4-icon-theme
    xfce.xfce4-mailwatch-plugin
    xfce.xfce4-mpc-plugin
    xfce.xfce4-netload-plugin
    xfce.xfce4-notes-plugin
    xfce.xfce4-notifyd
    xfce.xfce4-panel
    xfce.xfce4-panel-profiles
    xfce.xfce4-power-manager
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-screensaver
    xfce.xfce4-screenshooter
    xfce.xfce4-sensors-plugin
    xfce.xfce4-session
    xfce.xfce4-settings
    xfce.xfce4-systemload-plugin
    xfce.xfce4-taskmanager
    xfce.xfce4-terminal
    xfce.xfce4-time-out-plugin
    xfce.xfce4-timer-plugin
    xfce.xfce4-verve-plugin
    xfce.xfce4-volumed-pulse
    xfce.xfce4-weather-plugin
    xfce.xfce4-whiskermenu-plugin
    xfce.xfce4-windowck-plugin
    xfce.xfce4-xkb-plugin

    python3Full
    wmctrl
    xarchiver
    xorg.xwininfo
  ];
}
