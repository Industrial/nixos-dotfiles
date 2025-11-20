# River - Dynamic Tiling Wayland Compositor with Desktop Integration
{
  pkgs,
  settings,
  ...
}: {
  programs = {
    river = {
      enable = true;
      package = pkgs.river;
      xwayland = {
        enable = true;
      };
    };
  };

  # Use GDM as display manager (same as GNOME)
  services.displayManager.gdm.enable = true;

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
    };

    systemPackages = with pkgs; [
      # River and ecosystem
      river
      bun # For river init script
      rofi # Application launcher
      brightnessctl # Backlight control (replaces light)

      # Top Bar
      waybar

      # Notification Daemon
      mako

      # Desktop Integration Tools
      networkmanagerapplet # WiFi/Network GUI (system tray)
      networkmanager_dmenu # NetworkManager dmenu launcher
      blueman # Bluetooth manager GUI
      pavucontrol # Audio control GUI

      # Polkit for authentication dialogs
      polkit_gnome

      # System utilities
      wireplumber # Audio system

      # File manager
      nautilus

      # Terminal
      alacritty

      # GNOME Keyring for password management
      gnome.gnome-keyring

      # Tools for nested Wayland/X11 sessions (development/testing)
      weston
      cage # Wayland kiosk compositor (preferred for nested Wayland)
      waypipe # Wayland application forwarding
      xwayland # X11 compatibility layer for Wayland
    ];
  };

  # XDG Portal for application integration
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Polkit configuration
  security.polkit.enable = true;

  # GNOME Keyring for password storage (works with browsers, etc.)
  services.gnome.gnome-keyring.enable = true;

  # Audio system (WirePlumber/PipeWire)
  hardware.pulseaudio.enable = false; # Disable if using PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Link River config to user's home directory
  system.activationScripts.river-config = pkgs.lib.stringAfter ["etc"] ''
    mkdir -p /home/${settings.username}/.config/river
    # River init script should be created by user or we can provide a template
    # The init script should start desktop integration tools:
    #   waybar &
    #   mako &
    #   polkit-gnome-authentication-agent-1 &
    #   nm-applet --indicator &
    #   blueman-applet &
    #   gnome-keyring-daemon --start --components=ssh &
  '';
}
