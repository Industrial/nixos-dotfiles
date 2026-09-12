{...}: {
  programs = {
    nixvim = {
      opts = {
        # Show line numbers.
        number = true;
      };

      plugins = {
        # Shows the context you are in on the top of the buffer.
        barbecue = {
          enable = true;
        };

        # Shows indentation levels with thin vertical lines.
        indent-blankline = {
          enable = true;
        };

        # Highlights usages of the keyword under the cursor (using TreeSitter / LSP)
        illuminate = {
          enable = true;
        };
      };

      opts = {
        # Display a column with signs when necessary.
        signcolumn = "auto:1-9";

        # Highlight the line the cursor is on.
        cursorline = true;
      };
    };
  };

  # Panel for showing warnings and errors.
  programs.nixvim.plugins.trouble = {
    enable = true;

    settings = {
      position = "bottom";
      height = 10;
      # icons config removed - now defaults to enabled with proper icon set
      mode = "workspace_diagnostics";
      fold_open = "";
      fold_closed = "";
    };
  };

  # Popup for output messages.
  programs.nixvim.plugins.noice = {
    enable = true;

    settings = {
      lsp = {
        override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
          "cmp.entry.get_documentation" = true;
        };
      };

      presets = {
        bottom_search = true;
        command_palette = true;
        long_message_to_split = true;
        inc_rename = false;
        lsp_doc_border = true;
      };
    };
  };

  # Keybindings for Trouble
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>xx";
      action = "<cmd>Trouble diagnostics toggle<cr>";
      options = {
        desc = "Diagnostics (Trouble)";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>xX";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
      options = {
        desc = "Buffer Diagnostics";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>xL";
      action = "<cmd>Trouble loclist toggle<cr>";
      options = {
        desc = "Location List";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>xQ";
      action = "<cmd>Trouble qflist toggle<cr>";
      options = {
        desc = "Quickfix List";
        silent = true;
      };
    }
  ];

  programs.nixvim.extraConfigLua = ''
    local whichKey = require('which-key')

    whichKey.add({
      { "<leader>x", group = "Diagnostics" },
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List" },
    })
  '';
}
