-- Huginn: StarLite tablet internal panel (2160x1440 @ 3:2).
-- Output name is usually eDP-1; confirm with `hyprctl monitors` after first boot.

hl.monitor({
  output = "eDP-1",
  mode = "2160x1440@60",
  position = "auto",
  scale = 1,
  bitdepth = 8,
})
