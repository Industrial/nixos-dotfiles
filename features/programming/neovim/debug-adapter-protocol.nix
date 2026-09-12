{pkgs, ...}: {
  programs.nixvim.plugins = {
    # Debug Adapter Protocol
    dap = {
      enable = true;

      adapters = {
        executables = {
          # LLDB for Rust/C/C++
          lldb = {
            command = "${pkgs.lldb}/bin/lldb-vscode";
          };
        };
      };

      configurations = {
        # Rust debugging
        rust = [
          {
            name = "Launch";
            type = "lldb";
            request = "launch";
            program = ''\''${workspaceFolder}/target/debug/''${workspaceFolderBasename}'';
            cwd = ''\''${workspaceFolder}'';
            stopOnEntry = false;
            args = [];
          }
          {
            name = "Launch (with args)";
            type = "lldb";
            request = "launch";
            program = ''\''${workspaceFolder}/target/debug/''${workspaceFolderBasename}'';
            cwd = ''\''${workspaceFolder}'';
            stopOnEntry = false;
            args = ''\''${function() return vim.fn.input('Args: '):split(' ') end}'';
          }
        ];
      };
    };

    # DAP UI - provides a visual debugging interface
    dap-ui = {
      enable = true;

      settings = {
        floating.mappings = {
          close = ["<Esc>" "q"];
        };
        layouts = [
          {
            elements = [
              {
                id = "scopes";
                size = 0.25;
              }
              {
                id = "breakpoints";
                size = 0.25;
              }
              {
                id = "stacks";
                size = 0.25;
              }
              {
                id = "watches";
                size = 0.25;
              }
            ];
            size = 40;
            position = "left";
          }
          {
            elements = [
              {
                id = "repl";
                size = 0.5;
              }
              {
                id = "console";
                size = 0.5;
              }
            ];
            size = 10;
            position = "bottom";
          }
        ];
      };
    };

    # Virtual text showing variable values inline
    dap-virtual-text = {
      enable = true;
    };

    # Python debugging
    dap-python = {
      enable = true;
    };
  };

  # Keybindings for debugging
  programs.nixvim.keymaps = [
    # Standard debugging keys (F5-F12)
    {
      mode = "n";
      key = "<F5>";
      action = "<cmd>lua require('dap').continue()<cr>";
      options = {
        desc = "Debug: Start/Continue";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<F10>";
      action = "<cmd>lua require('dap').step_over()<cr>";
      options = {
        desc = "Debug: Step Over";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<F11>";
      action = "<cmd>lua require('dap').step_into()<cr>";
      options = {
        desc = "Debug: Step Into";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<F12>";
      action = "<cmd>lua require('dap').step_out()<cr>";
      options = {
        desc = "Debug: Step Out";
        silent = true;
      };
    }
  ];

  # Additional debug commands via which-key
  programs.nixvim.extraConfigLua = ''
    local dap = require('dap')
    local dapui = require('dapui')
    local whichKey = require('which-key')

    -- Auto-open DAP UI when debugging starts
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end

    whichKey.add({
      { "<leader>d", group = "Debug" },
      { "<leader>db", function() dap.toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dB", function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Conditional Breakpoint" },
      { "<leader>dc", function() dap.continue() end, desc = "Continue" },
      { "<leader>dC", function() dap.run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>dd", function() dap.disconnect() end, desc = "Disconnect" },
      { "<leader>dg", function() dap.session() end, desc = "Get Session" },
      { "<leader>di", function() dap.step_into() end, desc = "Step Into" },
      { "<leader>do", function() dap.step_over() end, desc = "Step Over" },
      { "<leader>dO", function() dap.step_out() end, desc = "Step Out" },
      { "<leader>dp", function() dap.pause() end, desc = "Pause" },
      { "<leader>dr", function() dap.repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() dap.continue() end, desc = "Start" },
      { "<leader>dt", function() dap.terminate() end, desc = "Terminate" },
      { "<leader>du", function() dapui.toggle() end, desc = "Toggle UI" },
    })
  '';

  environment.systemPackages = with pkgs; [
    # Debug adapters
    lldb

    # Python debugger
    python3Packages.debugpy
  ];
}
