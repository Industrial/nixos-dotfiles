# Hyprland - Dynamic Tiling Wayland Compositor with Desktop Integration
# Integrates with NetworkManager, Bluetooth, and other GNOME services
# TODO: Integrate these plugins/functionalities:
# - https://github.com/raybbian/hyprtasking
{
  pkgs,
  lib,
  settings,
  ...
}: {
  programs = {
    hyprland = {
      enable = true;
      xwayland = {
        enable = true;
      };
    };
  };

  services = {
    xserver = {
      displayManager = {
        gdm = {
          enable = true;
        };
      };
    };

    gnome = {
      gnome-keyring.enable = true;
    };
  };

  system = {
    activationScripts = {
      hyprland-config = lib.stringAfter ["etc"] ''
        mkdir -p /home/${settings.username}/.config/hypr
        if [ ! -f /home/${settings.username}/.config/hypr/hyprland.conf ]; then
          ln -sfn /etc/xdg/hypr/hyprland.conf /home/${settings.username}/.config/hypr/hyprland.conf
        fi

        mkdir -p /home/${settings.username}/.config/hypr
        if [ ! -f /home/${settings.username}/.config/hypr/hypridle.conf ]; then
          ln -sfn /etc/xdg/hypr/hypridle.conf /home/${settings.username}/.config/hypr/hypridle.conf
        fi

        if [ ! -f /home/${settings.username}/.config/hypr/hyprpaper.conf ]; then
          ln -sfn /etc/xdg/hypr/hyprpaper.conf /home/${settings.username}/.config/hypr/hyprpaper.conf
        fi

        if [ ! -f /home/${settings.username}/.config/hypr/hyprsunset.conf ]; then
          ln -sfn /etc/xdg/hypr/hyprsunset.conf /home/${settings.username}/.config/hypr/hyprsunset.conf
        fi
      '';
    };
  };

  environment = {
    etc = {
      "xdg/hypr/hyprland.conf" = {
        source = ./hyprland.conf;
        mode = "0644";
      };
      "xdg/hypr/hypridle.conf" = {
        source = ./hypridle.conf;
        mode = "0644";
      };
      "xdg/hypr/hyprpaper.conf" = {
        source = ./hyprpaper.conf;
        mode = "0644";
      };
      "xdg/hypr/hyprsunset.conf" = {
        source = ./hyprsunset.conf;
        mode = "0644";
      };
      "xdg/ashell/config.toml" = {
        source = ./ashell.toml;
        mode = "0644";
      };
    };

    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    systemPackages = with pkgs; [
      # Hyprland ecosystem
      hyprland
      # Lock screen
      hyprlock
      # Idle screen
      hypridle
      # Wallpaper manager
      hyprpaper
      # Cursor theme manager
      hyprcursor
      # Blue-light filter / Night light
      hyprsunset
      # Bar
      ashell
      # Application launcher
      wofi
      # Notification daemon
      mako

      # WiFi/Network GUI (system tray)
      networkmanagerapplet
      # NetworkManager dmenu launcher
      networkmanager_dmenu
      # Bluetooth manager GUI
      blueman
      # Audio control GUI
      pavucontrol
      # Settings (optional)
      gnome-control-center

      # Polkit for authentication dialogs
      polkit_gnome

      # System utilities
      brightnessctl # Screen brightness control
      wireplumber # Audio system (usually handled by systemd)
      playerctl # Media player control

      # File manager
      nautilus

      # Terminal
      alacritty

      # GNOME Keyring for password management
      gnome-keyring
    ];
  };

  xdg = {
    portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };

  security = {
    polkit = {
      enable = true;
    };
  };
}
