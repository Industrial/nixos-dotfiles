# Ultimate GNOME Configuration - The Coolest and Bestest Setup
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Import dconf configuration
  imports = [
    ./dconf.nix
  ];

  # Core GNOME Services
  services = {
    gnome = {
      gnome-settings-daemon = {
        enable = true;
      };

      gnome-keyring = {
        enable = true;
      };

      core-shell = {
        enable = true;
      };

      core-os-services = {
        enable = true;
      };

      core-apps = {
        enable = true;
      };
    };

    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };

    desktopManager = {
      gnome = {
        enable = true;
      };
    };
  };

  # System Packages - Core GNOME Applications
  environment = {
    systemPackages = with pkgs; [
      # Core GNOME Applications
      evince
      eog
      gnome-screenshot
      shotwell
      gnome-disk-utility
      gparted
      gnome-keyring
      dialect
      file-roller
      gnome-calculator
      gnome-font-viewer
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

      # Beautiful Themes and Icons
      papirus-icon-theme
      tela-icon-theme
      nordzy-icon-theme
      candy-icons
      nordic
      dracula-theme
      catppuccin-gtk
      gruvbox-gtk-theme
      bibata-cursors
      nordzy-cursor-theme
      catppuccin-cursors

      # Beautiful Fonts
      inter
      jetbrains-mono
      fira-code
      material-design-icons
      font-awesome
      noto-fonts-emoji

      # Visual Enhancements
      gnomeExtensions.blur-my-shell
      gnomeExtensions.burn-my-windows
      gnomeExtensions.just-perfection
      gnomeExtensions.user-themes

      # # Productivity Powerhouses
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.gsconnect
      gnomeExtensions.quick-settings-tweaker

      # Media & Entertainment
      gnomeExtensions.sound-output-device-chooser
      gnomeExtensions.spotify-tray

      # Advanced Features
      gnomeExtensions.night-theme-switcher

      # Keep your existing extensions
      gnomeExtensions.tiling-shell
      gnomeExtensions.vitals
      gnomeExtensions.wifi-qrcode
      gnomeExtensions.media-controls
      gnomeExtensions.notification-banner-reloaded
      gnomeExtensions.another-window-session-manager
    ];

    # Performance optimizations
    variables = {
      NIXOS_OZONE_WL = "1";
      FREETYPE_PROPERTIES = "truetype:interpreter-version=40";
      GNOME_DISABLE_CRASH_DIALOG = "1";
      GNOME_DISABLE_CRASH_REPORTER = "1";
      __GL_THREADED_OPTIMIZATIONS = "1";
      __GL_YIELD = "NOTHING";
    };
  };

  # Qt Configuration
  # qt = {
  #   enable = true;
  #   platformTheme = "gnome";
  #   style = "adwaita-dark";
  # };

  # Font Configuration
  fonts = {
    packages = with pkgs; [
      inter
      jetbrains-mono
      fira-code
      material-design-icons
      font-awesome
      noto-fonts-emoji
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = ["Inter"];
        sansSerif = ["Inter"];
        monospace = ["JetBrains Mono"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  # XDG Desktop Portal
  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
      ];
    };
  };
}
