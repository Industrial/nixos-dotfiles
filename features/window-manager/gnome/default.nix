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
      gnome-music
      gnome-sound-recorder
      spot
      totem
      #   - Bittorrent
      fragments
      #   - Documents
      evince
      #   - Images
      eog
      gnome-photos
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
      wordbook # gnome-dictionary
      gnome-font-viewer

      # - Email
      # Email client.
      geary

      # - Development
      # Git GUI.
      gitg

      # - Games
      gnome-chess
      gnome-sudoku

      # - System
      # Edit Gnome / Dconf settings.
      dconf-editor
      gnome-applets
      gnome-backgrounds
      gnome-system-monitor

      gnome-console
      gnome-decoder
      gnome-graphs
      gnome-tweaks
      gnome-bluetooth
      gnome-characters
      gnome-clocks
      gnome-color-manager
      gnome-contacts
      gnome-control-center
      gnome-logs
      gnome-maps
      gnome-nettool
      gnome-panel
      gnome-session
      gnome-shell
      gnome-shell-extensions
      gnome-weather
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
