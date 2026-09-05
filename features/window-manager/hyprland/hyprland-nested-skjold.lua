-- Nested Hyprland session for testing Skjold panel.
-- Launch via: nested-hyprland
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
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = "rgba(fabd2fee)",
      inactive_border = "rgba(3c3836aa)",
    },
    layout = "dwindle",
    allow_tearing = false,
  },
  decoration = {
    rounding = 6,
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
  -- Launch Skjold panel
  hl.exec_cmd("skjold >>/tmp/skjold.log 2>&1")
end)

-- Manual restart if needed
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd("pkill -x skjold || true; sleep 0.2; skjold >>/tmp/skjold.log 2>&1"))

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
