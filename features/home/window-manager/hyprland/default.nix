{pkgs, ...}: {
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.extraConfig = ''
    monitor=DP-2,     1920x1080, 0x0,    1, transform, 1
    monitor=HDMI-A-1, 3840x2160, 1080x0, 1
    monitor=DP-1,     1920x1080, 4920x0, 1, transform, 1

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

      sensitivity = 0
    }

    general {
      gaps_in = 3
      gaps_out = 0
      border_size = 1
      layout = master
    }

    decoration {
      rounding = 0
      blur = yes
      blur_size = 3
      blur_passes = 1
      blur_new_optimizations = on

      drop_shadow = yes
      shadow_range = 4
      shadow_render_power = 3
      col.shadow = rgba(1a1a1aee)
    }

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

    dwindle {
      pseudotile = yes # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
      preserve_split = yes # you probably want this
    }

    master {
      allow_small_split = false
      special_scale_factor = 0.8
      mfact = 0.55
      new_is_master = true
      new_on_top = false
      no_gaps_when_only = false
      orientation = left
      inherit_fullscreen = true
      always_center_master = false
    }

    gestures {
      workspace_swipe = off
    }

    device:epic-mouse-v1 {
      sensitivity = -0.5
    }

    $mainMod = SUPER

    # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
    bind = $mainMod CTRL, O, exec, alacritty
    bind = $mainMod CTRL, Q, killactive,
    bind = $mainMod CTRL_ALT, Q, exit,

    bind = $mainMod CTRL, F, togglefloating,
    # bind = $mainMod, P, pseudo, # dwindle
    # bind = $mainMod, J, togglesplit, # dwindle

    # # Move focus with mainMod + arrow keys
    # bind = $mainMod, h, movefocus, l
    # bind = $mainMod, j, movefocus, d
    # bind = $mainMod, k, movefocus, u
    # bind = $mainMod, l, movefocus, r

    bind = $mainMod, j, cyclenext, prev
    bind = $mainMod, k, cyclenext,
    bind = $mainMod CTRL, j, swapnext, prev
    bind = $mainMod CTRL, k, swapnext,

    # Switch workspaces with mainMod + [0-9]
    bind = $mainMod, 1, moveworkspacetomonitor, 1 current
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, moveworkspacetomonitor, 2 current
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, moveworkspacetomonitor, 3 current
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, moveworkspacetomonitor, 4 current
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, moveworkspacetomonitor, 5 current
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, moveworkspacetomonitor, 6 current
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, moveworkspacetomonitor, 7 current
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, moveworkspacetomonitor, 8 current
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, moveworkspacetomonitor, 9 current
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, moveworkspacetomonitor, 0 current
    bind = $mainMod, 0, workspace, 10

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    bind = $mainMod CTRL, 1, movetoworkspacesilent, 1
    bind = $mainMod CTRL, 2, movetoworkspacesilent, 2
    bind = $mainMod CTRL, 3, movetoworkspacesilent, 3
    bind = $mainMod CTRL, 4, movetoworkspacesilent, 4
    bind = $mainMod CTRL, 5, movetoworkspacesilent, 5
    bind = $mainMod CTRL, 6, movetoworkspacesilent, 6
    bind = $mainMod CTRL, 7, movetoworkspacesilent, 7
    bind = $mainMod CTRL, 8, movetoworkspacesilent, 8
    bind = $mainMod CTRL, 9, movetoworkspacesilent, 9
    bind = $mainMod CTRL, 0, movetoworkspacesilent, 10

    # Scroll through existing workspaces with mainMod + scroll
    bind = $mainMod, mouse_down, workspace, e+1
    bind = $mainMod, mouse_up,   workspace, e-1

    # Move/resize windows with mainMod + LMB/RMB and dragging
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow
  '';

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 24;
        #modules-left = ["river/tags"];
      }
    ];
  };
}
