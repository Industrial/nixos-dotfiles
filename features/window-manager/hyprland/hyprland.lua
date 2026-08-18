-- Hyprland 0.55+ Lua configuration (replaces hyprlang when this file is present).
-- Docs: https://wiki.hypr.land/Configuring/Basics/Variables/
-- Legacy hyprlang mirror: ~/.config/hypr/hyprland.conf.hyprlang

-----------------
---- MONITOR ----
-----------------

-- 8K resolution: 7680x2160@59.99Hz
-- bitdepth 8: required for PipeWire screen share (Signal, WebRTC, etc.).
-- bitdepth,10 breaks or greys out capture on xdg-desktop-portal-hyprland.
-- https://wiki.hypr.land/Configuring/Monitors/#10-bit-support
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
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = false,
    },
  },

  general = {
    gaps_in = 3,
    gaps_out = 0,
    border_size = 1,
    col = {
      active_border = {
        colors = { "rgba(33ccffee)", "rgba(00ff99ee)" },
        angle = 45,
      },
      inactive_border = "rgba(595959aa)",
    },
    layout = "dwindle",
    allow_tearing = false,
  },

  decoration = {
    rounding = 0,
    blur = {
      enabled = true,
      size = 3,
      passes = 1,
    },
    -- TODO: this broke (hyprlang shadow block):
    -- shadow = { enabled = true, range = 4, render_power = 3, color = "rgba(1a1a1aee)" },
  },

  animations = {
    enabled = true,
  },

  xwayland = {
    force_zero_scaling = true,
  },
})

-- TODO: this broke
-- hl.config({
--   dwindle = {
--     pseudotile = true,
--     preserve_split = true,
--   },
-- })

----------------
---- CURVES ----
----------------

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

--------------------
---- ANIMATIONS ----
--------------------

-- Ported from hyprlang `animation = …` lines
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

----------------------------
---- ENVIRONMENT / CURSOR ----
----------------------------

-- Install hyprcursor themes to ~/.local/share/icons/
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
-- Caelestia wallpaper library (recursive categories under this dir)
hl.env("CAELESTIA_WALLPAPERS_DIR", "/data/Images/Wallpapers")

-----------------
---- AUTOSTART ----
-----------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
  -- Ordered: secrets → auth → clipboard → shell → applets
  hl.exec_cmd("gnome-keyring-daemon --start --components=ssh")
  hl.exec_cmd("hyprpolkitagent")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("bash -lc 'caelestia-shell >>/tmp/caelestia-shell.log 2>&1'")
  hl.exec_cmd("hyprsunset")
  -- Tray icons optional; Caelestia status icons are primary
  -- hl.exec_cmd("blueman-applet")
  -- hl.exec_cmd("nm-applet --indicator")
end)

-- TODO: this broke (hyprlang gestures block):
-- hl.config({ gestures = { workspace_swipe = false } })

-- TODO: this broke (hyprlang windowrule lines):
-- hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true })
-- hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
-- hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true })
-- hl.window_rule({ match = { class = "^(org.gnome.Settings)$" }, float = true })

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

-- Window
hl.bind("SUPER + CTRL + C", hl.dsp.window.close())
hl.bind("SUPER + CTRL + Q", hl.dsp.window.kill())
hl.bind("SUPER + CTRL + Space", hl.dsp.window.float({ action = "toggle" }))

-- Application
hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + CTRL + P", hl.dsp.global("caelestia:launcher"))

-- Focus
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))

-- Window movement
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + CTRL + J", hl.dsp.window.move({ direction = "d" }))

-- Workspaces: switch
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = 10 }))

-- Workspaces: move window
hl.bind("SUPER + CTRL + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + CTRL + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + CTRL + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + CTRL + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + CTRL + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + CTRL + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + CTRL + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + CTRL + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + CTRL + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))

-- Volume via wpctl (Caelestia OSD follows PipeWire); brightness/media via globals
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"))
hl.bind("XF86AudioPause", hl.dsp.global("caelestia:mediaToggle"))
hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"))
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"))
hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"))
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"))

-- Clipboard / emoji (Caelestia CLI)
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind("SUPER + CTRL + SHIFT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard -d"))
hl.bind("SUPER + CTRL + PERIOD", hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))

-- Screenshots / record (Caelestia CLI)
hl.bind("PRINT", hl.dsp.exec_cmd("caelestia screenshot"))
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("caelestia screenshot -r"))
hl.bind("SUPER + SHIFT + PRINT", hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind("SUPER + CTRL + PRINT", hl.dsp.exec_cmd("caelestia record"))

-- TODO (hyprlang): scroll workspaces with SUPER + wheel — wave 2
-- TODO (hyprlang): mouse drag/resize — wave 2
-- TODO (hyprlang): window rules / gestures — wave 2
