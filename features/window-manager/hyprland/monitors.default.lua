-- Fallback for hosts without a monitors.<hostname>.lua (e.g. mimir).

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
  bitdepth = 8,
})
