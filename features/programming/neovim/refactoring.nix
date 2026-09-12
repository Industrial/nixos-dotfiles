{...}: {
  programs.nixvim.plugins.refactoring = {
    enable = true;
    enableTelescope = true;
  };

  # Refactoring keybindings
  programs.nixvim.keymaps = [
    # Visual mode refactorings
    {
      mode = "x";
      key = "<leader>re";
      action = "<cmd>lua require('refactoring').refactor('Extract Function')<cr>";
      options = {
        desc = "Extract Function";
        silent = true;
      };
    }
    {
      mode = "x";
      key = "<leader>rf";
      action = "<cmd>lua require('refactoring').refactor('Extract Function To File')<cr>";
      options = {
        desc = "Extract to File";
        silent = true;
      };
    }
    {
      mode = "x";
      key = "<leader>rv";
      action = "<cmd>lua require('refactoring').refactor('Extract Variable')<cr>";
      options = {
        desc = "Extract Variable";
        silent = true;
      };
    }
    {
      mode = "x";
      key = "<leader>ri";
      action = "<cmd>lua require('refactoring').refactor('Inline Variable')<cr>";
      options = {
        desc = "Inline Variable";
        silent = true;
      };
    }
    # Normal mode refactorings
    {
      mode = "n";
      key = "<leader>rb";
      action = "<cmd>lua require('refactoring').refactor('Extract Block')<cr>";
      options = {
        desc = "Extract Block";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>rI";
      action = "<cmd>lua require('refactoring').refactor('Inline Function')<cr>";
      options = {
        desc = "Inline Function";
        silent = true;
      };
    }
  ];

  # Refactoring menu via which-key
  programs.nixvim.extraConfigLua = ''
    local refactoring = require('refactoring')
    local whichKey = require('which-key')

    whichKey.add({
      { "<leader>r", group = "Refactor" },

      -- Visual mode refactorings
      { mode = "x", "<leader>re", function() refactoring.refactor('Extract Function') end, desc = "Extract Function" },
      { mode = "x", "<leader>rf", function() refactoring.refactor('Extract Function To File') end, desc = "Extract to File" },
      { mode = "x", "<leader>rv", function() refactoring.refactor('Extract Variable') end, desc = "Extract Variable" },
      { mode = "x", "<leader>ri", function() refactoring.refactor('Inline Variable') end, desc = "Inline Variable" },

      -- Normal mode refactorings
      { mode = "n", "<leader>rb", function() refactoring.refactor('Extract Block') end, desc = "Extract Block" },
      { mode = "n", "<leader>rI", function() refactoring.refactor('Inline Function') end, desc = "Inline Function" },

      -- Telescope picker for all refactorings
      { mode = {"n", "x"}, "<leader>rr", function() require('telescope').extensions.refactoring.refactors() end, desc = "Refactor Menu" },
    })
  '';
}
