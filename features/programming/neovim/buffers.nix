{...}: {
  # # load filetype plugins, indentation and turn syntax highlighting on
  # vim.cmd "filetype plugin indent on"

  # Buffers in the background.
  programs.nixvim.opts.hidden = true;

  # Don't wrap lines.
  programs.nixvim.opts.wrap = false;

  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<Tab>";
      action = ":bn<cr>";
    }
    {
      mode = "n";
      key = "<S-Tab>";
      action = ":bp<cr>";
    }
    {
      mode = "n";
      key = "<C-Q>";
      action = ":execute \"bnext|bdelete\" bufnr(\"%\")<CR>";
    }
  ];

  programs.nixvim.extraConfigLua = ''
    require("which-key").register({
      b = {
        name = "Buffers",
        b = { "<cmd>Telescope buffers<cr>", "Buffers" },
        d = { "<cmd>execute \"bnext|bdelete\" bufnr(\"%\")<CR>", "Delete" },
        w = { "<cmd>execute \"bnext|bwipeout\" bufnr(\"%\")<CR>", "Wipeout" },
        n = { "<cmd>bn<cr>", "Next" },
        p = { "<cmd>bp<cr>", "Previous" },
      },
    }, {
      prefix = "<leader>"
    })
  '';
}
