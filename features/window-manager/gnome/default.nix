# Ultimate GNOME Configuration - The Coolest and Bestest Setup
{
  pkgs,
  lib,
  config,
  settings,
  ...
}: {
  # Import dconf configuration and workspace setup
  imports = [
    ./dconf.nix
    ./workspace-setup.nix
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
      catppuccin-gtk
      bibata-cursors
      nordzy-cursor-theme
      catppuccin-cursors

      # Beautiful Fonts
      inter
      jetbrains-mono
      fira-code
      material-design-icons
      font-awesome
      noto-fonts-color-emoji

      # Visual Enhancements
      gnomeExtensions.blur-my-shell
      gnomeExtensions.burn-my-windows
      gnomeExtensions.just-perfection
      gnomeExtensions.user-themes

      # # Productivity Powerhouses
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.gsconnect
      # gnomeExtensions.quick-settings-tweaker is gone from nixpkgs — upstream
      # stopped at GNOME 48, so it is absent from both supported extension sets
      # (gnome49Extensions, gnome50Extensions).

      # Advanced Features
      gnomeExtensions.night-theme-switcher

      # Keep your existing extensions
      gnomeExtensions.tiling-shell
      gnomeExtensions.vitals
      gnomeExtensions.wifi-qrcode
      gnomeExtensions.media-controls
      gnomeExtensions.notification-banner-reloaded
      gnomeExtensions.another-window-session-manager

      # Workspace Management
      gnomeExtensions.auto-move-windows
      wmctrl
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
      noto-fonts-color-emoji
    ];
    fontconfig = {
      enable = true;
      # `monospace` is deliberately absent. It used to be ["JetBrains Mono"], written without
      # mkDefault, which silently beat the mkDefault that stylix's fontconfig target writes
      # from `stylix.fonts.monospace.name` -- so the fleet asked for IosevkaTerm in three
      # places (stylix, alacritty.toml, ghostty's config) and resolved the generic monospace
      # alias to a fourth font. The alias now has exactly one writer, stylix, and agrees with
      # what the terminals request.
      #
      # This feature is only ever imported from profiles/desktop.nix, which also imports
      # features/window-manager/stylix and stylix's own NixOS module, so there is no host
      # where dropping this line leaves the alias undefined.
      #
      # serif/sansSerif stay: Inter for UI text is a GNOME look someone chose on purpose,
      # and it is not what the terminals ask for.
      defaultFonts = {
        serif = ["Inter"];
        sansSerif = ["Inter"];
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

  # Match Hyprland monitor mode on DP-1 (Mutter reads ~/.config/monitors.xml).
  system.activationScripts.gnome-monitors = lib.stringAfter ["etc"] ''
    mkdir -p /home/${settings.username}/.config
    ln -sfn ${./monitors.xml} /home/${settings.username}/.config/monitors.xml
  '';
}
