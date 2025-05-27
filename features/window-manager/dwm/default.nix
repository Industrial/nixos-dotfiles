# DWM is a window manager.
{pkgs, ...}: let
  dwmOverlay = import ./overlays/my-dwm.nix {inherit pkgs;};

  startDwmSessionScript = pkgs.writeShellScriptBin "start-dwm-session" ''
    #!${pkgs.bash}/bin/bash
    dwm-status &
    exec ${pkgs.my-dwm}/bin/dwm
  '';

  startDwmXephyrScript = pkgs.writeShellScriptBin "start-dwm-xephyr" ''
    #!${pkgs.bash}/bin/bash
    DISPLAY_NUM=1
    while [ -f "/tmp/.X$DISPLAY_NUM-lock" ]; do
      DISPLAY_NUM=$DISPLAY_NUM + 1
    done
    XEPHYR_DISPLAY=":$DISPLAY_NUM"
    XEPHYR_GEOMETRY="1600x900"
    Xephyr "$XEPHYR_DISPLAY" -screen "$XEPHYR_GEOMETRY" -ac -br -noreset & xephyr_pid=$!
    sleep 1
    export DISPLAY="$XEPHYR_DISPLAY"
    ${startDwmSessionScript}/bin/start-dwm-session
    kill "$xephyr_pid"
    wait "$xephyr_pid" 2>/dev/null
  '';
in {
  nixpkgs.overlays = [dwmOverlay];

  environment.systemPackages = with pkgs; [
    # DWM
    my-dwm

    # Our DWM session script (used by display manager and Xephyr script)
    startDwmSessionScript

    # Script to launch DWM in Xephyr
    startDwmXephyrScript

    # Screen Lock
    slock

    # Ctrl-p Menu
    dmenu

    # Notification Daemon
    dunst

    # Compositor for X11.
    picom

    # Provides `startx` command
    xorg.xinit
  ];

  services = {
    xserver = {
      # Ensure the dwm-status feature is enabled if you want dwm-status to be available
      # This can be done in your host configuration: features.window-manager.dwm-status.enable = true;
      displayManager = {
        session = [
          {
            manage = "desktop";
            name = "dwm";
            start = ''
              ${startDwmSessionScript}/bin/start-dwm-session
            '';
          }
        ];
      };
    };
  };
}
