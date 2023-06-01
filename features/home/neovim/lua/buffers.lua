local smartBufferDelete
smartBufferDelete = function()
  local lastBuffer = vim.fn.bufnr('%')
  vim.cmd("bnext")
  return vim.cmd("bdelete " .. tostring(lastBuffer))
end
local smartBufferWipeout
smartBufferWipeout = function()
  local lastBuffer = vim.fn.bufnr('%')
  vim.cmd("bnext")
  return vim.cmd("bwipeout " .. tostring(lastBuffer))
end
return (function()
  local whichkey = require("which-key")
  vim.cmd("filetype plugin indent on")
  vim.opt.hidden = true
  vim.opt.wrap = false
  vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<cr>", { })
  vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<cr>", { })
  vim.keymap.set("n", "<C-Q>", smartBufferWipeout, {
    noremap = true
  })
  return whichkey.register({
    b = {
      name = "Buffers",
      b = {
        "<cmd>Telescope buffers<cr>",
        "Buffers"
      },
      d = {
        smartBufferDelete,
        "Delete"
      },
      w = {
        smartBufferWipeout,
        "Wipeout"
      },
      n = {
        "<cmd>BufferLineCycleNext<cr>",
        "Next"
      },
      p = {
        "<cmd>BufferLineCyclePrev<cr>",
        "Previous"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)()
