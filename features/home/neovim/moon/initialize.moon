-- TODO: Find a place for which-key configuration.
whichkey = require 'which-key'

whichkey.setup {
-- plugins = {
--   marks = false,
--   registers = false,
--   spelling = { enabled = false, suggestions = 20 },
--   presets = {
--     operators = false,
--     motions = false,
--     text_objects = false,
--     windows = false,
--     nav = false,
--     z = false,
--     g = false,
--   },
--   window = { border = 'single', position = 'top', margin = { 1, 0, 1, 0 }, padding = { 2, 2, 2, 2 } },
--   layout = { height = { min = 4, max = 25 }, width = { min = 20, max = 50 }, spacing = 3, align = 'center' },
-- },
}

--(require 'backups')!
--(require 'buffers')!
--(require 'colorschemes')!
--(require 'completion')!
--(require 'copy-paste')!
--(require 'debugger')!
--(require 'file-tabs')!
--(require 'file-tree-sidebar')!
--(require 'folds')!
--(require 'indentation')!
--(require 'line-numbers')!
--(require 'movement')!
--(require 'quickfix')!
--(require 'save-file')!
--(require 'search')!
--(require 'splits')!
--(require 'status-line')!
--(require 'visual-information')!

-- Disable NetRW
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set the map leader to space
vim.g.mapleader = ' '
