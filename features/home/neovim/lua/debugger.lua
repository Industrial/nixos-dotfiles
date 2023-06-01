local lua
lua = function()
  local dap = require("dap")
  dap.configurations.lua = {
    {
      type = "nlua",
      request = "attach",
      name = "Attach to running Neovim instance"
    }
  }
  dap.adapters.nlua = function(callback, config)
    return callback({
      type = "server",
      host = config.host or "127.0.0.1",
      port = config.port or 8086
    })
  end
end
local python
python = function()
  local dapPython = require("dap-python")
  return dapPython.setup("~/.virtualenvs/debugpy/bin/python")
end
local nodejs
nodejs = function()
  local dap = require("dap")
  local dapVscodeJs = require("dap-vscode-js")
  dapVscodeJs.setup({
    adapters = {
      "pwa-node",
      "pwa-chrome",
      "pwa-msedge",
      "node-terminal",
      "pwa-extensionHost"
    }
  })
  for _, language in ipairs({
    "typescript",
    "javascript"
  }) do
    dap.configurations[language] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = "${workspaceFolder}"
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}"
      },
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Jest Tests",
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/jest/bin/jest.js",
          "--runInBand"
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen"
      }
    }
  end
end
local interface
interface = function()
  local dapui = require("dapui")
  return dapui.setup()
end
return (function()
  local whichkey = require("which-key")
  local dapui = require("dapui")
  whichkey.register({
    d = {
      name = "Debug",
      d = {
        dapui.toggle,
        "Toggle DAP UI"
      },
      c = {
        "<cmd>DapContinue<cr>",
        "Continue"
      },
      s = {
        "<cmd>DapTerminate<cr>",
        "Stop"
      },
      b = {
        "<cmd>DapToggleBreakpoint<cr>",
        "Breakpoint"
      },
      r = {
        "<cmd>DapRestartFrame<cr>",
        "Breakpoint"
      },
      j = {
        "<cmd>DapStepOver<cr>",
        "Step Over"
      },
      J = {
        "<cmd>DapStepInto<cr>",
        "Step Into"
      },
      K = {
        "<cmd>DapStepOut<cr>",
        "Step Out"
      }
    }
  }, {
    prefix = "<leader>"
  })
  interface()
  lua()
  return python()
end)()
