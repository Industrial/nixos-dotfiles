{pkgs, ...}: {
  services = {
    gnome = {
      core-os-services = {
        enable = true;
      };
      core-shell = {
        enable = true;
      };
      core-utilities = {
        enable = true;
      };
      gnome-keyring = {
        enable = true;
      };
    };
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
      # - Media
      #   - Audio
      gnome.gnome-sound-recorder
      spot
      totem
      #   - Bittorrent
      fragments
      #   - Documents
      evince
      #   - Images
      eog
      gnome-screenshot
      shotwell
      #   - Video
      clapper

      # - Disks
      gnome-disk-utility
      gparted

      # - Security
      authenticator
      gnome-keyring
      gnome-secrets

      # - Office
      dialect
      file-roller
      gnome-calculator
      gnome-calendar
      gnome-dictionary
      gnome-font-viewer

      # - Email
      geary

      # - Development
      gitg

      gnome-console
      gnome-decoder
      gnome-graphs
      gnome-photos
      gnome-system-monitor
      gnome-tweaks
      gnome.gnome-applets
      gnome.gnome-backgrounds
      gnome.gnome-bluetooth
      gnome.gnome-characters
      gnome.gnome-chess
      gnome.gnome-clocks
      gnome.gnome-color-manager
      gnome.gnome-contacts
      gnome.gnome-control-center
      gnome.gnome-logs
      gnome.gnome-maps
      gnome.gnome-music
      gnome.gnome-nettool
      gnome.gnome-panel
      gnome.gnome-session
      gnome.gnome-shell
      gnome.gnome-shell-extensions
      gnome.gnome-sudoku
      gnome.gnome-weather
      nautilus
      papers
      seahorse
      wayfarer

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
