{...}: {
  programs = {
    nixvim = {
      opts = {
        # Buffers in the background.
        hidden = true;

        # Don't wrap lines.
        wrap = false;
      };

      keymaps = [
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

      extraConfigLua = ''
        local whichKey = require("which-key")

        whichKey.add({
          { "<leader>b", group = "Buffers" },
          { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
          { "<leader>bd", "<cmd>Bdelete<cr>", desc = "Delete" },
          { "<leader>bn", "<cmd>bn<cr>", desc = "Next" },
          { "<leader>bp", "<cmd>bp<cr>", desc = "Previous" },
          { "<leader>bw", "<cmd>Bwipeout<cr>", desc = "Wipeout" },
        })
      '';
    };
  };
}
