{...}: {
  # Open a Modal dialog to search through many possible things.
  # TODO: I have keybinds for this somewhere. Why not here?
  programs.nixvim.plugins.telescope.enable = true;

  # Jump through the document quickly. Supports Search and TreeSitter.
  # TODO: https://github.com/folke/flash.nvim
  programs.nixvim.plugins.flash.enable = true;

  # programs.nixvim.keymaps = [
  #   {
  #     mode = "n";
  #     key = "s";
  #     action = "<cmd>bn<cr>";
  #   }
  #   {
  #     mode = "n";
  #     key = "<S-Tab>";
  #     action = "<cmd>bp<cr>";
  #   }
  #   {
  #     mode = "n";
  #     key = "<C-Q>";
  #     action = "<cmd>Bwipeout<cr>";
  #   }
  # ];

  # TODO: Can't seem to call Lua in `programs.nixvim.keymaps`.
  programs.nixvim.extraConfigLua = ''
    local flash = require('flash')

    vim.keymap.set({'n', 'x'}, 's',     flash.jump,              { noremap = true })
    vim.keymap.set({'n', 'x'}, 'S',     flash.treesitter,        { noremap = true })

    require("which-key").register({
      s = {
        name = "Search",
        s = { flash.jump, "Search" },
        S = { flash.treesitter, "TreeSitter" },
      },
    }, {
      prefix = "<leader>"
    })
  '';
}

# vim.keymap.set({'x'},      'R',     flash.treesitter_search, { noremap = true })
# vim.keymap.set({'c'},      '<c-s>', flash.toggle,            { noremap = true })
