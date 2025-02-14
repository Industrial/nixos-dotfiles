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

  # programs.nixvim.extraConfigLua = let
  #   toLuaObject = programs.nixvim.lib.helpers.toLuaObject;
  # in ''
  #   require("which-key").add(${nixvim.lib.helpers.toLuaObject({
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
}
