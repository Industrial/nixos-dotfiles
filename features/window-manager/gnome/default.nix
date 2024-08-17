{pkgs, ...}: {
  services = {
    xserver = {
      displayManager = {
        gdm = {
          enable = true;
        };
      };
      desktopManager = {
        gnome = {
          enable = true;
        };
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      gnome-tweaks

      # - Tiling Window Manager
      gnomeExtensions.pop-shell
      # - Transparent Inactive Windows
      gnomeExtensions.focus
      # - Bar Indicators
      #   - System Monitor
      gnomeExtensions.vitals
      #   - Workspaces
      gnomeExtensions.simple-workspaces-bar
      #   - Key Manager
      gnomeExtensions.keyman
      #   - WiFi QR Code
      gnomeExtensions.wifi-qrcode
      #   - Media Controls
      gnomeExtensions.media-controls
      # - Notifications
      gnomeExtensions.notification-banner-reloaded
      # - Session Manager
      gnomeExtensions.another-window-session-manager
    ];
  };
}
