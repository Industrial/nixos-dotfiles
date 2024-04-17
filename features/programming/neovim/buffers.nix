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
      action = "<cmd>bn<cr>";
    }
    {
      mode = "n";
      key = "<S-Tab>";
      action = "<cmd>bp<cr>";
    }
    {
      mode = "n";
      key = "<C-Q>";
      action = "<cmd>Bwipeout<cr>";
    }
  ];

  # programs.nixvim.extraConfigLua = let
  #   toLuaObject = programs.nixvim.lib.helpers.toLuaObject;
  # in ''
  #   require("which-key").register(${nixvim.lib.helpers.toLuaObject({
  #     b = {
  #       name = "Buffers";
  #       b = [ "<cmd>Telescope buffers<cr>" "Buffers" ];
  #       d = [ "<cmd>Bdelete<cr>" "Delete" ];
  #       w = [ "<cmd>Bwipeout<cr>" "Wipeout" ];
  #       n = [ "<cmd>bn<cr>" "Next" ];
  #       p = [ "<cmd>bp<cr>" "Previous" ];
  #     };
  #   })}, ${nixvim.lib.helpers.toLuaObject({
  #     prefix = "<leader>";
  #   })})
  # '';

  programs.nixvim.extraConfigLua = ''
    require("which-key").register({
      b = {
        name = "Buffers",
        b = { "<cmd>Telescope buffers<cr>", "Buffers" },
        d = { "<cmd>Bdelete<cr>", "Delete" },
        w = { "<cmd>Bwipeout<cr>", "Wipeout" },
        n = { "<cmd>bn<cr>", "Next" },
        p = { "<cmd>bp<cr>", "Previous" },
      },
    }, {
      prefix = "<leader>"
    })
  '';
}
