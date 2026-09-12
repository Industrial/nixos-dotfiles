{pkgs, ...}: {
  programs.nixvim.plugins = {
    # Git signs in the gutter (hunks, additions, deletions)
    gitsigns = {
      enable = true;

      settings = {
        signs = {
          add = {text = "│";};
          change = {text = "│";};
          delete = {text = "_";};
          topdelete = {text = "‾";};
          changedelete = {text = "~";};
          untracked = {text = "┆";};
        };

        current_line_blame = false;

        on_attach = ''
          function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation
            map('n', ']c', function()
              if vim.wo.diff then return ']c' end
              vim.schedule(function() gs.next_hunk() end)
              return '<Ignore>'
            end, {expr=true, desc='Next Git Hunk'})

            map('n', '[c', function()
              if vim.wo.diff then return '[c' end
              vim.schedule(function() gs.prev_hunk() end)
              return '<Ignore>'
            end, {expr=true, desc='Previous Git Hunk'})
          end
        '';
      };
    };

    # Full Git UI (like VSCode's Source Control panel)
    neogit = {
      enable = true;

      settings = {
        integrations = {
          telescope = true;
          diffview = true;
        };

        kind = "split";

        commit_popup = {
          kind = "split";
        };

        popup = {
          kind = "split";
        };
      };
    };

    # Diff view for comparing changes
    diffview = {
      enable = true;

      settings = {
        enhanced_diff_hl = true;

        view = {
          default = {
            layout = "diff2_horizontal";
          };
          merge_tool = {
            layout = "diff3_horizontal";
          };
        };
      };
    };
  };

  # Git keybindings
  programs.nixvim.keymaps = [
    # Gitsigns hunk actions
    {
      mode = "n";
      key = "<leader>hs";
      action = "<cmd>Gitsigns stage_hunk<cr>";
      options = {
        desc = "Stage Hunk";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>hr";
      action = "<cmd>Gitsigns reset_hunk<cr>";
      options = {
        desc = "Reset Hunk";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>hu";
      action = "<cmd>Gitsigns undo_stage_hunk<cr>";
      options = {
        desc = "Undo Stage Hunk";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>hp";
      action = "<cmd>Gitsigns preview_hunk<cr>";
      options = {
        desc = "Preview Hunk";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>hb";
      action = "<cmd>Gitsigns blame_line<cr>";
      options = {
        desc = "Blame Line";
        silent = true;
      };
    }
  ];

  # Git commands via which-key
  programs.nixvim.extraConfigLua = ''
    local neogit = require('neogit')
    local whichKey = require('which-key')

    whichKey.add({
      { "<leader>g", group = "Git" },
      { "<leader>gg", function() neogit.open() end, desc = "Git Status (Neogit)" },
      { "<leader>gc", function() neogit.open({ "commit" }) end, desc = "Git Commit" },
      { "<leader>gp", function() neogit.open({ "push" }) end, desc = "Git Push" },
      { "<leader>gP", function() neogit.open({ "pull" }) end, desc = "Git Pull" },
      { "<leader>gl", function() neogit.open({ "log" }) end, desc = "Git Log" },
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View" },
      { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Close Diff View" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch History" },
      { "<leader>gm", "<cmd>DiffviewOpen main<cr>", desc = "Diff with Main" },

      { "<leader>h", group = "Git Hunks" },
      { "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", desc = "Stage Hunk" },
      { "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", desc = "Reset Hunk" },
      { "<leader>hS", "<cmd>Gitsigns stage_buffer<cr>", desc = "Stage Buffer" },
      { "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", desc = "Undo Stage" },
      { "<leader>hR", "<cmd>Gitsigns reset_buffer<cr>", desc = "Reset Buffer" },
      { "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", desc = "Preview Hunk" },
      { "<leader>hb", "<cmd>Gitsigns blame_line<cr>", desc = "Blame Line" },
      { "<leader>hd", "<cmd>Gitsigns diffthis<cr>", desc = "Diff This" },
    })
  '';

  environment.systemPackages = with pkgs; [
    # Git itself
    git
  ];
}
