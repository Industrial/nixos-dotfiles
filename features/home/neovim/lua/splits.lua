return (function()
  local whichkey = require("which-key")
  vim.opt.splitbelow = true
  vim.opt.splitright = true
  vim.keymap.set("n", "<C-h>", "<C-w>h", {
    noremap = true
  })
  vim.keymap.set("n", "<C-j>", "<C-w>j", {
    noremap = true
  })
  vim.keymap.set("n", "<C-k>", "<C-w>k", {
    noremap = true
  })
  vim.keymap.set("n", "<C-l>", "<C-w>l", {
    noremap = true
  })
  return whichkey.register({
    w = {
      name = "Window",
      c = {
        "<C-W>c",
        "Close"
      },
      h = {
        "<C-W>h",
        "Left"
      },
      H = {
        "<C-W>5>",
        "Left (Resize)"
      },
      j = {
        "<C-W>j",
        "Down"
      },
      J = {
        ":resize +5",
        "Down (Resize)"
      },
      k = {
        "<C-W>k",
        "Up"
      },
      K = {
        ":resize -5",
        "Up (Resize)"
      },
      l = {
        "<C-W>l",
        "Right"
      },
      L = {
        "<C-W>5<",
        "Right (Resize)"
      },
      ["="] = {
        "<C-W>=",
        "Balance"
      },
      s = {
        "<C-W>s",
        "Horizontal"
      },
      ["-"] = {
        "<C-W>s",
        "Horizontal"
      },
      v = {
        "<C-W>v",
        "Vertical"
      },
      ["|"] = {
        "<C-W>v",
        "Vertical"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)()
