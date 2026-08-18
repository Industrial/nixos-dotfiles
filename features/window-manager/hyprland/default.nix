# Hyprland - Dynamic Tiling Wayland Compositor with Desktop Integration
# Integrates with NetworkManager, Bluetooth, and other GNOME services
# Lua config (hyprland.lua) requires Hyprland 0.55+; pin via flake input `hyprland`
# (nixpkgs-unstable may still ship an older release).
# See https://hypr.land/news/26_lua/ and https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
{
  pkgs,
  lib,
  settings,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  hyprPkgs = inputs.hyprland.packages.${system};
  hyprlandPkg = hyprPkgs.hyprland;
  hyprlandPortal = hyprPkgs.xdg-desktop-portal-hyprland;
  # Live config under the git checkout (edit + `hyprctl reload` / restart Hyprland — no rebuild).
  dotfilesHyprDir = "${settings.userdir}/.dotfiles/features/window-manager/hyprland";
  hasCaelestia = inputs ? caelestia-shell;
  caelestiaShellPkg =
    if hasCaelestia
    then inputs.caelestia-shell.packages.${system}.with-cli
    else null;
  # with-cli wraps the shell but does not put `caelestia` on system PATH.
  caelestiaCliPkg =
    if hasCaelestia
    then inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.default
    else null;
  nestedCaelestiaLauncher = pkgs.writeShellScriptBin "nested-caelestia-hyprland" ''
    set -euo pipefail
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "nested-caelestia-hyprland: need a parent Wayland session" >&2
      exit 1
    fi
    export XDG_CURRENT_DESKTOP=Hyprland
    exec ${hyprlandPkg}/bin/Hyprland --config ${dotfilesHyprDir}/hyprland-nested-caelestia.lua
  '';
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

          if [ ! -f /home/${settings.username}/.config/hypr/hyprsunset.conf ]; then
            ln -sfn /etc/xdg/hypr/hyprsunset.conf /home/${settings.username}/.config/hypr/hyprsunset.conf
          fi

          ln -sfn "${dotfilesHyprDir}/xdph.conf" /home/${settings.username}/.config/hypr/xdph.conf
          if [ -f "${dotfilesHyprDir}/hyprland-nested-caelestia.lua" ]; then
            ln -sfn "${dotfilesHyprDir}/hyprland-nested-caelestia.lua" /home/${settings.username}/.config/hypr/hyprland-nested-caelestia.lua
          fi

          # Caelestia: managed shell.json + wallpaper library symlink for the picker
          mkdir -p /home/${settings.username}/.config/caelestia
          mkdir -p /home/${settings.username}/Pictures
          if [ -f "${dotfilesHyprDir}/caelestia/shell.json" ]; then
            ln -sfn "${dotfilesHyprDir}/caelestia/shell.json" /home/${settings.username}/.config/caelestia/shell.json
          fi
          if [ -d /data/Images/Wallpapers ]; then
            ln -sfn /data/Images/Wallpapers /home/${settings.username}/Pictures/Wallpapers
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
        "xdg/hypr/hyprland-nested-caelestia.lua" = {
          source = ./hyprland-nested-caelestia.lua;
          mode = "0644";
        };
        "xdg/hypr/hyprland.conf.hyprlang" = {
          source = ./hyprland.conf.hyprlang;
          mode = "0644";
        };
        "xdg/hypr/hyprsunset.conf" = {
          source = ./hyprsunset.conf;
          mode = "0644";
        };
        "xdg/caelestia/shell.json" = {
          source = ./caelestia/shell.json;
          mode = "0644";
        };
        "xdg/hypr/xdph.conf" = {
          source = ./xdph.conf;
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
        # Cursor theme manager
        hyprcursor
        # Blue-light filter / Night light
        hyprsunset

        # WiFi/Network GUI (kept for settings apps; tray via Caelestia)
        networkmanagerapplet
        networkmanager_dmenu
        blueman
        pavucontrol
        gnome-control-center

        # Polkit (Hyprland-native)
        hyprpolkitagent

        # Caelestia CLI / desktop utilities
        grim
        slurp
        swappy
        cliphist
        wl-clipboard
        fuzzel
        gpu-screen-recorder

        # Qt Wayland
        qt5.qtwayland
        qt6.qtwayland

        # System utilities
        brightnessctl
        wireplumber
        playerctl

        nautilus
        alacritty
        gnome-keyring
      ]
      ++ lib.optionals hasCaelestia [
        caelestiaShellPkg
        caelestiaCliPkg
        nestedCaelestiaLauncher
        material-symbols
        nerd-fonts.caskaydia-cove
      ];
    };

    xdg = {
      portal = {
        enable = true;
        # Do not enable xdg-desktop-portal-wlr alongside Hyprland's portal — they
        # race for ScreenCast and break Signal/WebRTC share (black/blank remote).
        # programs.hyprland.portalPackage already provides xdg-desktop-portal-hyprland.
        wlr.enable = false;
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
