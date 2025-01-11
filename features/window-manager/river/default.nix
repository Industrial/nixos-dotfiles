# River is a tiling window manager for Wayland.
{pkgs, ...}: {
  programs = {
    river = {
      enable = true;
      package = pkgs.river;
      xwayland = {
        enable = true;
      };
      # TODO: What are these?
      extraPackages = with pkgs; [termite rofi light];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      bun

      # Top Bar
      polybarFull

      # Notification Daemon
      mako

      # Application Launcher
      rofi
    ];
  };
}
