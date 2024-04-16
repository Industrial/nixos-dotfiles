{...}: {
  # https://github.com/nvim-neo-tree/neo-tree.nvim
  programs.nixvim.plugins.neo-tree.enable = true;

  programs.nixvim.extraConfigLua = ''
    require("which-key").register({
      t = {
        name = "Tree",
        t = { "<cmd>Neotree toggle<cr>", "Toggle" },
        f = { "<cmd>Neotree reveal<cr>", "Find File" },
      }
    }, {
      prefix = "<leader>"
    })
  '';
}
