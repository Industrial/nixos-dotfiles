{pkgs, ...}: {
  services = {
    gnome = {
      core-os-services = {
        enable = true;
      };

      core-shell = {
        enable = true;
      };

      core-apps = {
        enable = true;
      };

      gnome-keyring = {
        enable = true;
      };
    };
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

  environment = {
    systemPackages = with pkgs; [
      # - Media
      #   - Documents
      evince
      #   - Images
      eog
      gnome-screenshot
      shotwell

      # - Disks
      gnome-disk-utility
      gparted

      # - Security
      gnome-keyring

      # - Office
      dialect
      file-roller
      gnome-calculator
      gnome-font-viewer

      # - System
      # Edit Gnome / Dconf settings.
      dconf-editor
      gnome-applets
      gnome-backgrounds
      gnome-system-monitor

      gnome-console
      gnome-decoder
      gnome-tweaks
      gnome-bluetooth
      gnome-characters
      gnome-clocks
      gnome-control-center
      gnome-panel
      gnome-session
      gnome-shell
      gnome-shell-extensions
      nautilus

      # - Tiling Window Manager
      #gnomeExtensions.pop-shell
      gnomeExtensions.tiling-shell
      # - Transparent Inactive Windows
      gnomeExtensions.focus
      # - Bar Indicators
      #   - System Monitor
      gnomeExtensions.vitals
      #   - Workspaces
      gnomeExtensions.simple-workspaces-bar
      # TODO: This one is no longer available?
      # #   - Key Manager
      # gnomeExtensions.keyman
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
