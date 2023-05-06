smartBufferDelete = () ->
  lastBuffer = vim.fn.bufnr('%')
  vim.cmd "bnext"
  vim.cmd "bdelete #{lastBuffer}"

smartBufferWipeout = () ->
  lastBuffer = vim.fn.bufnr('%')
  vim.cmd "bnext"
  vim.cmd "bwipeout #{lastBuffer}"

() ->
  whichkey = require "which-key"

  -- load filetype plugins, indentation and turn syntax highlighting on
  vim.cmd "filetype plugin indent on"

  -- Buffers in the background.
  vim.opt.hidden = true

  -- don't wrap lines
  vim.opt.wrap = false

  vim.keymap.set "n", "<Tab>", ":BufferLineCycleNext<cr>", {}
  vim.keymap.set "n", "<S-Tab>", ":BufferLineCyclePrev<cr>", {}

  vim.keymap.set "n", "<C-Q>", smartBufferWipeout, {
    noremap: true,
  }

  whichkey.register {
    b:
      name: "Buffers",
      b: { "<cmd>Telescope buffers<cr>", "Buffers" },
      d: { smartBufferDelete, "Delete" },
      w: { smartBufferWipeout, "Wipeout" },
      n: { "<cmd>BufferLineCycleNext<cr>", "Next" },
      p: { "<cmd>BufferLineCyclePrev<cr>", "Previous" },
  }, {
    prefix: "<leader>"
  }
