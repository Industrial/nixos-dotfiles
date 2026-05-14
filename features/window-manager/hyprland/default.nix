# Hyprland - Dynamic Tiling Wayland Compositor with Desktop Integration
# Integrates with NetworkManager, Bluetooth, and other GNOME services
# Lua config (hyprland.lua) requires Hyprland 0.55+; pin via flake input `hyprland`
# (nixpkgs-unstable may still ship an older release).
# See https://hypr.land/news/26_lua/ and https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
# TODO: Integrate these plugins/functionalities:
# - https://github.com/raybbian/hyprtasking
{
  pkgs,
  lib,
  settings,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  hyprPkgs = inputs.hyprland.packages.${system};
  hyprlandPkg = hyprPkgs.hyprland;
  hyprlandPortal = hyprPkgs.xdg-desktop-portal-hyprland;
  # Live config under the git checkout (edit + `hyprctl reload` / restart Hyprland — no rebuild).
  dotfilesHyprDir = "${settings.userdir}/.dotfiles/features/window-manager/hyprland";
in
assert lib.assertMsg (inputs ? hyprland) ''
  features/window-manager/hyprland: add a `hyprland` flake input, for example:
    hyprland.url = "github:hyprwm/hyprland";
  (Avoid `hyprland.inputs.nixpkgs.follows` unless your nixpkgs has all deps, e.g. lua5_5.)
''; {
  programs = {
    hyprland = {
      enable = true;
      package = hyprlandPkg;
      portalPackage = hyprlandPortal;
      xwayland = {
        enable = true;
      };
    };
  };

  services = {
    displayManager = {
      gdm = {
        enable = true;
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
        # Prefer the mutable checkout so edits apply after reload/restart without nixos-rebuild.
        if [ -f "${dotfilesHyprDir}/hyprland.lua" ]; then
          ln -sfn "${dotfilesHyprDir}/hyprland.lua" /home/${settings.username}/.config/hypr/hyprland.lua
        else
          ln -sfn /etc/xdg/hypr/hyprland.lua /home/${settings.username}/.config/hypr/hyprland.lua
        fi
        if [ -f "${dotfilesHyprDir}/hyprland.conf.hyprlang" ]; then
          ln -sfn "${dotfilesHyprDir}/hyprland.conf.hyprlang" /home/${settings.username}/.config/hypr/hyprland.conf.hyprlang
        else
          ln -sfn /etc/xdg/hypr/hyprland.conf.hyprlang /home/${settings.username}/.config/hypr/hyprland.conf.hyprlang
        fi

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
      "xdg/hypr/hyprland.lua" = {
        source = ./hyprland.lua;
        mode = "0644";
      };
      "xdg/hypr/hyprland.conf.hyprlang" = {
        source = ./hyprland.conf.hyprlang;
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
      # Hyprland (pinned to inputs.hyprland for 0.55+ / Lua configs)
      hyprlandPkg
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
