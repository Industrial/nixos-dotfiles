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
  monitorProfile = pkgs.writeShellScriptBin "hypr-monitor-profile" (
    let
      raw = builtins.readFile ./hypr-monitor-profile.sh;
      # Drop shebang; writeShellScriptBin supplies one.
      body =
        if lib.hasPrefix "#!" raw
        then lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" raw))
        else raw;
    in
      body
  );
  # Nested Hyprland session for testing ashell bar
  nestedAshellLauncher = pkgs.writeShellScriptBin "nested-ashell-hyprland" ''
    set -euo pipefail
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "nested-ashell-hyprland: need a parent Wayland session" >&2
      exit 1
    fi
    export XDG_CURRENT_DESKTOP=Hyprland
    exec ${hyprlandPkg}/bin/Hyprland --config ${dotfilesHyprDir}/hyprland-nested-ashell.lua
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

          monitors_src="${dotfilesHyprDir}/monitors.${settings.hostname}.lua"
          if [ ! -f "''$monitors_src" ]; then
            monitors_src="${dotfilesHyprDir}/monitors.default.lua"
          fi
          ln -sfn "''$monitors_src" /home/${settings.username}/.config/hypr/monitors.lua

          # ashell config
          mkdir -p /home/${settings.username}/.config/ashell
          if [ -f "${dotfilesHyprDir}/ashell/config.toml" ]; then
            ln -sfn "${dotfilesHyprDir}/ashell/config.toml" /home/${settings.username}/.config/ashell/config.toml
          fi

          # hyprlock config
          if [ -f "${dotfilesHyprDir}/hyprlock.conf" ]; then
            ln -sfn "${dotfilesHyprDir}/hyprlock.conf" /home/${settings.username}/.config/hypr/hyprlock.conf
          fi

          # hyprtoolkit config (for hyprlauncher theming)
          if [ -f "${dotfilesHyprDir}/hyprtoolkit.conf" ]; then
            ln -sfn "${dotfilesHyprDir}/hyprtoolkit.conf" /home/${settings.username}/.config/hypr/hyprtoolkit.conf
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
        "xdg/hypr/hyprsunset.conf" = {
          source = ./hyprsunset.conf;
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

        # WiFi/Network GUI (kept for settings apps; ashell has tray)
        networkmanagerapplet
        networkmanager_dmenu
        blueman
        pavucontrol

        # Polkit (Hyprland-native)
        hyprpolkitagent

        # Screenshot / clipboard utilities
        grim
        slurp
        swappy
        cliphist
        wl-clipboard
        fuzzel
        gpu-screen-recorder

        # Wallpaper
        awww

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

        monitorProfile

        # ashell bar + hyprlauncher
        ashell
        hyprlauncher
        nestedAshellLauncher
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

    # Wallpaper rotation timer (15 minutes)
    systemd.user.services.awww-random = {
      description = "Random wallpaper switcher";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${dotfilesHyprDir}/awww-random.sh";
      };
    };

    systemd.user.timers.awww-random = {
      description = "Random wallpaper every 15 minutes";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "15min";
      };
    };
  }
