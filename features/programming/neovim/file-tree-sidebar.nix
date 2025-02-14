{...}: {
  programs = {
    nixvim = {
      plugins = {
        # https://github.com/nvim-neo-tree/neo-tree.nvim
        neo-tree = {
          enable = true;
        };
      };

      extraConfigLua = ''
        local whichKey = require("which-key")

        whichKey.add({
          { "<leader>t", group = "Tree" },
          { "<leader>tf", "<cmd>Neotree reveal<cr>", desc = "Find File" },
          { "<leader>tt", "<cmd>Neotree toggle<cr>", desc = "Toggle" },
        })
      '';
    };
  };
}
