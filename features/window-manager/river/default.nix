# River is a tiling window manager for Wayland.
{pkgs, ...}: {
  programs = {
    river = {
      enable = true;
      package = pkgs.river;
      xwayland = {
        enable = true;
      };
      # TODO: Why are these here instead of environment.systemPackages?
      extraPackages = with pkgs; [rofi light];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      bun

      # Top Bar
      waybar
      # polybarFull

      # Notification Daemon
      mako

      # Application Launcher
      rofi

      # Tools for nested Wayland/X11 sessions (development/testing)
      weston
      cage # Wayland kiosk compositor (preferred for nested Wayland)
      waypipe # Wayland application forwarding
      xwayland # X11 compatibility layer for Wayland
    ];
  };
}
