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
    telescopeBuiltin = require("telescope.builtin")
    findFiles = function()
      telescopeBuiltin.find_files({
        find_command = { "rg", "--no-ignore", "--files" },
        hidden = true,
      })
    end
    vim.keymap.set("n", "<C-p>", findFiles, {
      noremap = true,
      silent = true,
    })

    require("which-key").add({
      { "<leader>f", group = "Find" },
      { "<leader>f/", telescopeBuiltin.current_buffer_fuzzy_find, desc = "in buffer" },
      { "<leader>fC", telescopeBuiltin.command_history, desc = "command history" },
      { "<leader>fb", telescopeBuiltin.buffers, desc = "buffers" },
      { "<leader>fc", telescopeBuiltin.commands, desc = "commands" },
      { "<leader>ff", telescopeBuiltin.live_grep, desc = "in files" },
      { "<leader>fg", group = "Git" },
      { "<leader>fgb", telescopeBuiltin.git_branches, desc = "branches" },
      { "<leader>fgc", telescopeBuiltin.git_commits, desc = "commits" },
      { "<leader>fgd", telescopeBuiltin.git_bcommits, desc = "diff" },
      { "<leader>fgs", telescopeBuiltin.git_status, desc = "status" },
      { "<leader>fgt", telescopeBuiltin.git_stash, desc = "stash" },
      { "<leader>fh", telescopeBuiltin.help_tags, desc = "help tags" },
      { "<leader>fl", group = "LSP" },
      { "<leader>fld", telescopeBuiltin.lsp_definitions, desc = "definitions" },
      { "<leader>fli", telescopeBuiltin.lsp_implementations, desc = "implementations" },
      { "<leader>flr", telescopeBuiltin.lsp_references, desc = "references" },
      { "<leader>fls", telescopeBuiltin.lsp_document_symbols, desc = "document symbols" },
      { "<leader>flt", telescopeBuiltin.lsp_type_definitions, desc = "type definitions" },
      { "<leader>flw", telescopeBuiltin.lsp_workspace_symbols, desc = "workspace symbols" },
      { "<leader>fp", telescopeBuiltin.find_files, desc = "files" },
      { "<leader>fq", telescopeBuiltin.quickfix, desc = "quickfix" },
      { "<leader>fr", telescopeBuiltin.registers, desc = "registers" },
    })

    local flash = require('flash')

    vim.keymap.set({'n', 'x'}, 's',     flash.jump,              { noremap = true })
    vim.keymap.set({'n', 'x'}, 'S',     flash.treesitter,        { noremap = true })

    require("which-key").add({
      { "<leader>s", group = "Search" },
      { "<leader>sS", flash.jump, desc = "TreeSitter" },
      { "<leader>ss", flash.treesitter, desc = "Search" },
    })
  '';

  # vim.keymap.set({'x'},      'R',     flash.treesitter_search, { noremap = true })
  # vim.keymap.set({'c'},      '<c-s>', flash.toggle,            { noremap = true })
}
