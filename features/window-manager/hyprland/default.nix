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
      sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
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
      drop_shadow = yes
      shadow_range = 4
      shadow_render_power = 3
      col.shadow = rgba(1a1a1aee)
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

    # Gestures
    gestures {
      workspace_swipe = off
    }

    # Window Rules
    windowrule = float, ^(pavucontrol)$
    windowrule = float, ^(blueman-manager)$
    windowrule = float, ^(nm-connection-editor)$
    windowrule = float, ^(org.gnome.Settings)$

    # Application Keybinds
    bind = SUPER, Return, exec, ${pkgs.alacritty}/bin/alacritty
    bind = SUPER, Q, killactive,
    bind = SUPER, M, exit,
    bind = SUPER, E, exec, ${pkgs.nautilus}/bin/nautilus
    bind = SUPER, V, togglefloating,
    bind = SUPER, R, exec, ${pkgs.wofi}/bin/wofi --show drun
    bind = SUPER, P, exec, ${pkgs.wofi}/bin/wofi --show powermenu
    bind = SUPER, L, exec, ${pkgs.hyprlock}/bin/hyprlock

    # Move focus with mainMod + arrow keys
    bind = SUPER, left, movefocus, l
    bind = SUPER, right, movefocus, r
    bind = SUPER, up, movefocus, u
    bind = SUPER, down, movefocus, d

    # Switch workspaces with mainMod + [0-9]
    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4
    bind = SUPER, 5, workspace, 5
    bind = SUPER, 6, workspace, 6
    bind = SUPER, 7, workspace, 7
    bind = SUPER, 8, workspace, 8
    bind = SUPER, 9, workspace, 9
    bind = SUPER, 0, workspace, 10

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
    bind = SUPER SHIFT, 5, movetoworkspace, 5
    bind = SUPER SHIFT, 6, movetoworkspace, 6
    bind = SUPER SHIFT, 7, movetoworkspace, 7
    bind = SUPER SHIFT, 8, movetoworkspace, 8
    bind = SUPER SHIFT, 9, movetoworkspace, 9
    bind = SUPER SHIFT, 0, movetoworkspace, 10

    # Scroll through existing workspaces with mainMod + scroll
    bind = SUPER, mouse_down, workspace, e+1
    bind = SUPER, mouse_up, workspace, e-1

    # Move/resize windows with mainMod + LMB/RMB and dragging
    bindm = SUPER, mouse:272, movewindow
    bindm = SUPER, mouse:273, resizewindow

    # Desktop Integration - Launch GUI tools
    bind = SUPER SHIFT, N, exec, ${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu
    bind = SUPER SHIFT, B, exec, ${pkgs.blueman}/bin/blueman-manager
    bind = SUPER SHIFT, A, exec, ${pkgs.pavucontrol}/bin/pavucontrol
    bind = SUPER SHIFT, S, exec, ${pkgs.gnome.gnome-settings-daemon}/bin/gnome-control-center

    # Audio
    bind = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bind = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bind = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    # Brightness
    bind = , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set +10%
    bind = , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 10%-

    # XWayland
    xwayland {
      force_zero_scaling = true
    }

    # Autostart desktop integration tools
    exec-once = ${pkgs.waybar}/bin/waybar
    exec-once = ${pkgs.mako}/bin/mako
    exec-once = ${pkgs.polkit_gnome}/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    exec-once = ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
    exec-once = ${pkgs.blueman}/bin/blueman-applet
    exec-once = ${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --start --components=ssh
  '';
in {
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    nvidiaPatches = false; # Set to true if using NVIDIA
  };

  # Use GDM as display manager (same as GNOME)
  services.displayManager.gdm.enable = true;

  # Environment variables
  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    systemPackages = with pkgs; [
      # Hyprland ecosystem
      hyprland
      hyprlock
      hypridle
      waybar
      wofi
      mako

      # Desktop Integration Tools
      networkmanagerapplet # WiFi/Network GUI (system tray)
      networkmanager_dmenu # NetworkManager dmenu launcher
      blueman # Bluetooth manager GUI
      pavucontrol # Audio control GUI
      gnome.gnome-control-center # Settings (optional)

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
      gnome.gnome-keyring
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

  # Copy Hyprland config using environment.etc (accessible to user)
  environment.etc."xdg/hypr/hyprland.conf" = {
    source = hyprlandConfig;
    mode = "0644";
  };

  # Link config to user's home directory via activation script
  # Users can override by creating ~/.config/hypr/hyprland.conf
  system.activationScripts.hyprland-config = lib.stringAfter ["etc"] ''
    mkdir -p /home/${settings.username}/.config/hypr
    if [ ! -f /home/${settings.username}/.config/hypr/hyprland.conf ]; then
      ln -sfn /etc/xdg/hypr/hyprland.conf /home/${settings.username}/.config/hypr/hyprland.conf
    fi
  '';
}
