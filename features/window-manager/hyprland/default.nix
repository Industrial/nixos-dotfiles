# Hyprland - Dynamic Tiling Wayland Compositor with Desktop Integration
# Integrates with NetworkManager, Bluetooth, and other GNOME services
{
  pkgs,
  lib,
  settings,
  ...
}: let
  # Hyprland configuration with desktop integration
  hyprlandConfig = pkgs.writeText "hyprland.conf" ''
    # Monitor Configuration
    monitor=,preferred,auto,1

    # Input Configuration
    input {
      kb_layout = us
      kb_variant =
      kb_model =
      kb_options =
      kb_rules =

      follow_mouse = 1
      touchpad {
        natural_scroll = no
      }

      # -1.0 - 1.0, 0 means no modification.
      sensitivity = 0
    }

    # General Configuration
    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 2
      col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
      col.inactive_border = rgba(595959aa)

      layout = dwindle
      allow_tearing = false
    }

    # Decoration
    decoration {
      rounding = 10
      blur {
        enabled = true
        size = 3
        passes = 1
      }
      # TODO: this broke.
      # drop_shadow = yes
      # shadow_range = 4
      # shadow_render_power = 3
      # col.shadow = rgba(1a1a1aee)
    }

    # Animations
    animations {
      enabled = yes
      bezier = myBezier, 0.05, 0.9, 0.1, 1.05
      animation = windows, 1, 7, myBezier
      animation = windowsOut, 1, 7, default, popin 80%
      animation = border, 1, 10, default
      animation = borderangle, 1, 8, default
      animation = fade, 1, 7, default
      animation = workspaces, 1, 6, default
    }

    # Dwindle Layout
    dwindle {
      pseudotile = yes
      preserve_split = yes
    }

    # TODO: this broke.
    # # Gestures
    # gestures {
    #   workspace_swipe = off
    # }

    # TODO: this broke.
    # # Window Rules
    # windowrule = float, ^(pavucontrol)$
    # windowrule = float, ^(blueman-manager)$
    # windowrule = float, ^(nm-connection-editor)$
    # windowrule = float, ^(org.gnome.Settings)$

    # Keybinds
      # Session
        # Reload Hyprland configuration
        bind = SUPER CTRL SHIFT, R, exec, ${pkgs.hyprland}/bin/hyprctl reload
        # Quit Hyprland
        bind = SUPER CTRL SHIFT, Q, exec, ${pkgs.hyprland}/bin/hyprctl exit
        # Lock screen
        bind = SUPER CTRL SHIFT, L, exec, ${pkgs.hyprlock}/bin/hyprlock
      # Window
        # Kill active window
        bind = SUPER CTRL, Q, killactive,
        # Toggle floating
        bind = SUPER CTRL, Space, togglefloating,
      # Application
        # Open terminal
        bind = SUPER, Return, exec, ${pkgs.alacritty}/bin/alacritty
        # Open application
        bind = SUPER, P, exec, ${pkgs.wofi}/bin/wofi
      # Focus
        # Move focus left
        bind = SUPER, h, movefocus, l
        # Move focus right
        bind = SUPER, l, movefocus, r
        # Move focus up
        bind = SUPER, k, movefocus, u
        # Move focus down
        bind = SUPER, j, movefocus, d
      # Workspaces
        # Switch
          # Switch to workspace 1
          bind = SUPER, 1, workspace, 1
          # Switch to workspace 2
          bind = SUPER, 2, workspace, 2
          # Switch to workspace 3
          bind = SUPER, 3, workspace, 3
          # Switch to workspace 4
          bind = SUPER, 4, workspace, 4
          # Switch to workspace 5
          bind = SUPER, 5, workspace, 5
          # Switch to workspace 6
          bind = SUPER, 6, workspace, 6
          # Switch to workspace 7
          bind = SUPER, 7, workspace, 7
          # Switch to workspace 8
          bind = SUPER, 8, workspace, 8
          # Switch to workspace 9
          bind = SUPER, 9, workspace, 9
          # Switch to workspace 10
          bind = SUPER, 0, workspace, 10
        # Move
          # Move to workspace 1
          bind = SUPER CTRL, 1, movetoworkspace, 1
          # Move to workspace 2
          bind = SUPER CTRL, 2, movetoworkspace, 2
          # Move to workspace 3
          bind = SUPER CTRL, 3, movetoworkspace, 3
          # Move to workspace 4
          bind = SUPER CTRL, 4, movetoworkspace, 4
          # Move to workspace 5
          bind = SUPER CTRL, 5, movetoworkspace, 5
          # Move to workspace 6
          bind = SUPER CTRL, 6, movetoworkspace, 6
          # Move to workspace 7
          bind = SUPER CTRL, 7, movetoworkspace, 7
          # Move to workspace 8
          bind = SUPER CTRL, 8, movetoworkspace, 8
          # Move to workspace 9
          bind = SUPER CTRL, 9, movetoworkspace, 9
          # Move to workspace 10
          bind = SUPER CTRL, 0, movetoworkspace, 10

    # Audio
      # Raise volume
      bind = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      # Lower volume
      bind = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      # Mute
      bind = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    # Brightness
      # Increase brightness
      bind = , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set +10%
      # Decrease brightness
      bind = , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 10%-

    # # Scroll through existing workspaces with mainMod + scroll
    # bind = SUPER, mouse_down, workspace, e+1
    # bind = SUPER, mouse_up, workspace, e-1

    # # Move/resize windows with mainMod + LMB/RMB and dragging
    # bindm = SUPER, mouse:272, movewindow
    # bindm = SUPER, mouse:273, resizewindow

    # # Desktop Integration - Launch GUI tools
    # bind = SUPER SHIFT, N, exec, ${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu
    # bind = SUPER SHIFT, B, exec, ${pkgs.blueman}/bin/blueman-manager
    # bind = SUPER SHIFT, A, exec, ${pkgs.pavucontrol}/bin/pavucontrol
    # bind = SUPER SHIFT, S, exec, ${pkgs.gnome-settings-daemon}/bin/gnome-control-center

    # XWayland
    xwayland {
      force_zero_scaling = true
    }

    # # Autostart desktop integration tools
    # exec-once = ${pkgs.waybar}/bin/waybar
    # exec-once = ${pkgs.mako}/bin/mako
    # exec-once = ${pkgs.polkit_gnome}/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    # exec-once = ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
    # exec-once = ${pkgs.blueman}/bin/blueman-applet
    # exec-once = ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=ssh
  '';
in {
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

  environment = {
    etc = {
      "xdg/hypr/hyprland.conf" = {
        source = hyprlandConfig;
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
      # Status bar
      waybar
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

  system = {
    activationScripts = {
      hyprland-config = lib.stringAfter ["etc"] ''
        mkdir -p /home/${settings.username}/.config/hypr
        if [ ! -f /home/${settings.username}/.config/hypr/hyprland.conf ]; then
          ln -sfn /etc/xdg/hypr/hyprland.conf /home/${settings.username}/.config/hypr/hyprland.conf
        fi
      '';
    };
  };
}
