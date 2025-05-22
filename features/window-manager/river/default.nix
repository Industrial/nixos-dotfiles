# River is a tiling window manager for Wayland.
{pkgs, ...}: {
  programs = {
    river = {
      enable = true;
      package = pkgs.river;
      xwayland = {
        enable = true;
      };
      # extraPackages were moved to systemPackages for consistency
    };
  };

  environment = {
    systemPackages = with pkgs; [
      bun
      rofi # Application launcher (moved from extraPackages)
      light # Backlight control (moved from extraPackages)

      # Top Bar
      waybar

      # Notification Daemon
      mako

      # Tools for nested Wayland/X11 sessions (development/testing)
      weston
      cage # Wayland kiosk compositor (preferred for nested Wayland)
      waypipe # Wayland application forwarding
      xwayland # X11 compatibility layer for Wayland
    ];
  };
}
