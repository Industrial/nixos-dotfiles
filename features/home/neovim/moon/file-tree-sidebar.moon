(() ->
  whichkey = require "which-key"
  nvimtree = require "nvim-tree"

  nvimtree.setup {
    disable_netrw: true
    sync_root_with_cwd: true
    reload_on_bufenter: true
    sort_by: "case_sensitive"
    view:
      adaptive_size: true
    renderer:
      group_empty: true
    filters:
      dotfiles: false
  }

  vim.keymap.set "n", "<C-t>", ":NvimTreeToggle<cr>|<C-w>p",
    noremap: true

  whichkey.register {
    t:
      name: "Tree"
      t: { "<cmd>NvimTreeToggle<cr>", "Toggle" }
      f: { "<cmd>NvimTreeFindFile<cr>", "Find File" }
      c: { "<cmd>NvimTreeCollapseKeepBuffers<cr>", "Collapse & Keep Buffers" }
      C: { "<cmd>NvimTreeCollapse<cr>", "Collapse" }
  }, {
    prefix: "<leader>"
  }
)!
