() ->
  -- Global copy/paste register delete/yank/paste in normal mode.
  vim.keymap.set "n", "<leader>d", '"+d', {}
  vim.keymap.set "n", "<leader>y", '"+y', {}
  vim.keymap.set "n", "<leader>p", '"+p', {}

  -- Mouse copy/paste register delete/yank/paste in normal mode.
  vim.keymap.set "n", "<leader>D", '"*d', {}
  vim.keymap.set "n", "<leader>Y", '"*y', {}
  vim.keymap.set "n", "<leader>P", '"*p', {}

  -- Global copy/paste register delete/yank/paste in visual mode.
  vim.keymap.set "v", "<C-v>", '"+p', {}
  vim.keymap.set "v", "<C-c>", '"+y', {}
  vim.keymap.set "v", "<C-x>", '"+d', {}
  -- Paste from Global Copy/Paste Register in Insert Mode.
  vim.keymap.set "i", "<C-v>", '<esc>"+pi', {}
