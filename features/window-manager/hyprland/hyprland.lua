-- Hyprland 0.55+ Lua configuration (replaces hyprlang when this file is present).
-- Docs: https://wiki.hypr.land/Configuring/Basics/Variables/
-- Legacy hyprlang mirror: ~/.config/hypr/hyprland.conf.hyprlang
-- Binds cheat sheet: BINDINGS.md

-----------------
---- MONITOR ----
-----------------

-- 8K ultrawide; bitdepth 8 required for PipeWire screen share.
hl.monitor({
  output = "DP-1",
  mode = "7680x2160@59.99",
  position = "auto",
  scale = 1,
  bitdepth = 8,
})

--------------------
---- LOOK & FEEL ----
--------------------

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = false,
    },
  },

  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 1,
    col = {
      active_border = {
        colors = { "rgba(fabd2fee)", "rgba(fe8019ee)" },
        angle = 45,
      },
      inactive_border = "rgba(3c3836aa)",
    },
    -- Master is more usable on 32:9 than dwindle alone.
    layout = "master",
    allow_tearing = false,
  },

  decoration = {
    rounding = 6,
    blur = {
      enabled = true,
      size = 3,
      passes = 1,
    },
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
  },

  animations = {
    enabled = true,
  },

  -- Note: window pseudotile is hl.dsp.window.pseudo(), not a dwindle key (0.55+).
  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "slave",
    mfact = 0.55,
    orientation = "left",
  },

  -- Trackpad workspace swipe is configured via hl.gesture() (0.55+), not gestures.*.

  misc = {
    -- 0 = off (Caelestia FAQ: VRR can flicker with shell)
    vrr = 0,
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },

  binds = {
    drag_threshold = 10,
  },

  xwayland = {
    force_zero_scaling = true,
  },
})

-- 3-finger horizontal swipe switches workspaces (laptops/tablets)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("CAELESTIA_WALLPAPERS_DIR", "/data/Images/Wallpapers")

-----------------
---- AUTOSTART ----
-----------------

hl.on("hyprland.start", function()
  hl.exec_cmd("gnome-keyring-daemon --start --components=ssh")
  hl.exec_cmd("hyprpolkitagent")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("bash -lc 'caelestia-shell >>/tmp/caelestia-shell.log 2>&1'")
  hl.exec_cmd("hyprsunset")
end)

--------------------
---- WINDOW RULES ----
--------------------

hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(org.gnome.Settings)$" }, float = true })
hl.window_rule({ match = { class = "^(org.gnome.Nautilus)$" }, float = false })

-- Prefer coding / browsing workspaces on open (silent)
hl.window_rule({ match = { class = "^(Alacritty)$" }, workspace = "1 silent" })
hl.window_rule({ match = { class = "^(librewolf|firefox|brave-browser)$" }, workspace = "2 silent" })

-- Caelestia layers: keep snappy, lightly blurred
hl.layer_rule({ match = { namespace = ".*caelestia.*" }, no_anim = false, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = ".*quickshell.*" }, blur = true, ignore_alpha = 0.3 })

---------------------
---- KEYBINDINGS ----
---------------------

-- Session / Caelestia shell
hl.bind("SUPER + CTRL + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("SUPER + CTRL + SHIFT + Q", hl.dsp.global("caelestia:session"))
hl.bind("SUPER + CTRL + SHIFT + L", hl.dsp.global("caelestia:lock"))
hl.bind("SUPER + CTRL + SHIFT + C", hl.dsp.global("caelestia:clearNotifs"))
hl.bind("SUPER + CTRL + SHIFT + B", hl.dsp.global("caelestia:sidebar"))
hl.bind(
  "SUPER + CTRL + ALT + R",
  hl.dsp.exec_cmd("bash -lc 'pkill -x caelestia-shell || true; sleep 0.2; caelestia-shell >>/tmp/caelestia-shell.log 2>&1'")
)
hl.bind("SUPER + CTRL + G", hl.dsp.exec_cmd("caelestia shell gameMode toggle"))
hl.bind(
  "SUPER + CTRL + SHIFT + M",
  hl.dsp.exec_cmd("$HOME/.dotfiles/features/window-manager/hyprland/hypr-monitor-profile.sh toggle")
)

-- Window
hl.bind("SUPER + CTRL + C", hl.dsp.window.close())
hl.bind("SUPER + CTRL + Q", hl.dsp.window.kill())
hl.bind("SUPER + CTRL + Space", hl.dsp.window.float({ action = "toggle" }))

-- Application
hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + CTRL + P", hl.dsp.global("caelestia:launcher"))

-- Focus / move
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + CTRL + J", hl.dsp.window.move({ direction = "d" }))

-- Workspaces
for i = 1, 10 do
  local key = tostring(i % 10)
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind("SUPER + CTRL + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special scratchpad
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratch"))
hl.bind("SUPER + CTRL + S", hl.dsp.window.move({ workspace = "special:scratch" }))

-- Mouse
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume / brightness / media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), { locked = true })

-- Clipboard
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind("SUPER + CTRL + SHIFT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard -d"))

-- Screenshots / record
hl.bind("PRINT", hl.dsp.exec_cmd("caelestia screenshot"))
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("caelestia screenshot -r"))
hl.bind("SUPER + SHIFT + PRINT", hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind("SUPER + CTRL + PRINT", hl.dsp.exec_cmd("caelestia record"))
