-- Nested Hyprland session for evaluating ashell bar.
-- Launch via: nested-ashell-hyprland
-- Uses ALT binds so they do not collide with the outer SUPER session.

-----------------
---- MONITOR ----
-----------------

-- Nested window: let Hyprland pick a reasonable virtual output.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

--------------------
---- LOOK & FEEL ----
--------------------

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
  },
  general = {
    gaps_in = 3,
    gaps_out = 3,
    border_size = 1,
    col = {
      active_border = "rgba(89b4faee)",
      inactive_border = "rgba(45475aaa)",
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
  },
  animations = {
    enabled = true,
  },
  xwayland = {
    force_zero_scaling = true,
  },
  misc = {
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
  },
})

-----------------
---- AUTOSTART ----
-----------------

hl.on("hyprland.start", function()
  -- Launch ashell bar
  hl.exec_cmd("ashell >>/tmp/nested-ashell.log 2>&1")
end)

-- Manual restart if needed (ALT+SHIFT+A)
hl.bind("ALT + SHIFT + A", hl.dsp.exec_cmd("pkill -x ashell || true; sleep 0.2; ashell >>/tmp/nested-ashell.log 2>&1"))

---------------------
---- KEYBINDINGS ----
---------------------

-- Exit nested compositor
hl.bind("ALT + SHIFT + Q", hl.dsp.exit())
hl.bind("ALT + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Window
hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind("ALT + Space", hl.dsp.window.float({ action = "toggle" }))

-- Terminal
hl.bind("ALT + Return", hl.dsp.exec_cmd("alacritty"))

-- App launcher (anyrun: Rust, GTK4, themeable, icons)
hl.bind("ALT + P", hl.dsp.exec_cmd("anyrun"))

-- Focus
hl.bind("ALT + H", hl.dsp.focus({ direction = "l" }))
hl.bind("ALT + L", hl.dsp.focus({ direction = "r" }))
hl.bind("ALT + K", hl.dsp.focus({ direction = "u" }))
hl.bind("ALT + J", hl.dsp.focus({ direction = "d" }))

-- Workspaces
hl.bind("ALT + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("ALT + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("ALT + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("ALT + 4", hl.dsp.focus({ workspace = 4 }))
