-- Nested Hyprland session for evaluating Caelestia Shell.
-- Launch via: nested-caelestia-hyprland
-- Uses ALT binds so they do not collide with the outer SUPER session.
-- Does NOT start ashell / wofi / mako.

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
      active_border = "rgba(9ccbfbee)",
      inactive_border = "rgba(595959aa)",
    },
    layout = "dwindle",
    allow_tearing = false,
  },
  decoration = {
    rounding = 8,
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
  -- `caelestia` CLI is not on system PATH with with-cli alone; use the shell
  -- binary (on PATH) and log failures for diagnosis.
  hl.exec_cmd("bash -lc 'caelestia-shell >>/tmp/nested-caelestia-shell.log 2>&1'")
end)

-- Manual start if autostart fails/races
hl.bind("ALT + SHIFT + C", hl.dsp.exec_cmd("bash -lc 'caelestia-shell >>/tmp/nested-caelestia-shell.log 2>&1'"))

---------------------
---- KEYBINDINGS ----
---------------------

-- Exit nested compositor
hl.bind("ALT + SHIFT + Q", hl.dsp.exit())
hl.bind("ALT + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Window
hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind("ALT + Space", hl.dsp.window.float({ action = "toggle" }))

-- Terminal (alacritty already on PATH from parent/system packages)
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
