{pkgs, ...}: {
  programs.nixvim.plugins = {
    # Test runner with inline results
    neotest = {
      enable = true;

      adapters = {
        # Rust testing
        rust = {
          enable = true;
        };

        # Python testing
        python = {
          enable = true;
          settings = {
            runner = "pytest";
            python = "${pkgs.python3}/bin/python3";
          };
        };
      };

      settings = {
        # Show quick summary in quickfix list
        quickfix = {
          enabled = true;
          open = false;
        };

        # Show test status as virtual text
        status = {
          enabled = true;
          virtual_text = true;
          signs = true;
        };

        # Animated running indicator
        icons = {
          running_animated = ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"];
        };
      };
    };

    # Test coverage visualization (already enabled, keeping it)
    coverage = {
      enable = true;
      settings = {
        auto_reload = true;
        highlights = {
          covered = {fg = "#C3E88D";};
          uncovered = {fg = "#F07178";};
        };
      };
    };
  };

  # Test runner keybindings
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>tr";
      action = "<cmd>lua require('neotest').run.run()<cr>";
      options = {
        desc = "Run Nearest Test";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tf";
      action = "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<cr>";
      options = {
        desc = "Run File Tests";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>td";
      action = "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>";
      options = {
        desc = "Debug Nearest Test";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ts";
      action = "<cmd>lua require('neotest').summary.toggle()<cr>";
      options = {
        desc = "Test Summary";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>to";
      action = "<cmd>lua require('neotest').output.open({enter = true})<cr>";
      options = {
        desc = "Test Output";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tp";
      action = "<cmd>lua require('neotest').output_panel.toggle()<cr>";
      options = {
        desc = "Test Output Panel";
        silent = true;
      };
    }
  ];

  # Test commands via which-key
  programs.nixvim.extraConfigLua = ''
    local neotest = require('neotest')
    local whichKey = require('which-key')

    whichKey.add({
      { "<leader>t", group = "Test" },
      { "<leader>ta", function() neotest.run.run(vim.fn.getcwd()) end, desc = "Run All Tests" },
      { "<leader>td", function() neotest.run.run({strategy = 'dap'}) end, desc = "Debug Test" },
      { "<leader>tf", function() neotest.run.run(vim.fn.expand('%')) end, desc = "Run File" },
      { "<leader>tl", function() neotest.run.run_last() end, desc = "Run Last" },
      { "<leader>to", function() neotest.output.open({enter = true}) end, desc = "Output" },
      { "<leader>tp", function() neotest.output_panel.toggle() end, desc = "Output Panel" },
      { "<leader>tr", function() neotest.run.run() end, desc = "Run Nearest" },
      { "<leader>ts", function() neotest.summary.toggle() end, desc = "Summary" },
      { "<leader>tS", function() neotest.run.stop() end, desc = "Stop" },
      { "<leader>tw", function() neotest.watch.toggle() end, desc = "Watch" },
    })
  '';

  environment.systemPackages = with pkgs; [
    # Python testing
    python3Packages.pytest
    python3Packages.pytest-cov
  ];
}
