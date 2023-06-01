local backupFiles
backupFiles = function()
  vim.opt.backup = true
  vim.opt.writebackup = true
  vim.opt.backupdir = vim.fn.expand("~/.config/nvim/backup")
  vim.opt.backupcopy = "yes"
end
local swapFiles
swapFiles = function()
  vim.opt.swapfile = true
  vim.opt.directory = vim.fn.expand("~/.config/nvim/temp")
end
local undoFiles
undoFiles = function()
  vim.opt.undofile = true
  vim.opt.undodir = vim.fn.expand("~/.config/nvim/undo")
end
(function()
  backupFiles()
  swapFiles()
  return undoFiles()
end)()
local smartBufferDelete
smartBufferDelete = function()
  local lastBuffer = vim.fn.bufnr('%')
  vim.cmd("bnext")
  return vim.cmd("bdelete " .. tostring(lastBuffer))
end
local smartBufferWipeout
smartBufferWipeout = function()
  local lastBuffer = vim.fn.bufnr('%')
  vim.cmd("bnext")
  return vim.cmd("bwipeout " .. tostring(lastBuffer))
end
(function()
  local whichkey = require("which-key")
  vim.cmd("filetype plugin indent on")
  vim.opt.hidden = true
  vim.opt.wrap = false
  vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<cr>", { })
  vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<cr>", { })
  vim.keymap.set("n", "<C-Q>", smartBufferWipeout, {
    noremap = true
  })
  return whichkey.register({
    b = {
      name = "Buffers",
      b = {
        "<cmd>Telescope buffers<cr>",
        "Buffers"
      },
      d = {
        smartBufferDelete,
        "Delete"
      },
      w = {
        smartBufferWipeout,
        "Wipeout"
      },
      n = {
        "<cmd>BufferLineCycleNext<cr>",
        "Next"
      },
      p = {
        "<cmd>BufferLineCyclePrev<cr>",
        "Previous"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)()
local base16
base16 = function()
  vim.g.base16colorspace = 256
end
(function()
  vim.opt.termguicolors = true
  return base16()
end)()
local astparser
astparser = function()
  local nvimTreeSitterConfigs = require("nvim-treesitter.configs")
  vim.opt.runtimepath:append("/home/tom/.config/nvim/treesitter_parsers")
  return nvimTreeSitterConfigs.setup({
    parser_install_dir = "/home/tom/.config/nvim/treesitter_parsers",
    ensure_installed = "all",
    sync_install = false,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false
    },
    autotag = {
      enable = true
    },
    rainbow = {
      enable = true,
      extended_mode = false,
      max_file_lines = nil
    },
    autopairs = {
      enable = true
    }
  })
end
local completepairs
completepairs = function()
  local nvimAutoPairs = require("nvim-autopairs")
  return nvimAutoPairs.setup({ })
end
local copilot
copilot = function()
  vim.g.copilot_enabled = true
  vim.g.copilot_filetypes = {
    ["*"] = true
  }
  local isDisplayingSuggestion
  isDisplayingSuggestion = function()
    local displayedSuggestion = vim.fn["copilot#GetDisplayedSuggestion"]()
    return displayedSuggestion and string.len(displayedSuggestion.text) > 0
  end
  local nextSuggestion
  nextSuggestion = function()
    if isDisplayingSuggestion() then
      return vim.fn["copilot#Next"]()
    else
      return vim.fn["copilot#Suggest"]()
    end
  end
  local previousSuggestion
  previousSuggestion = function()
    return vim.fn["copilot#Previous"]()
  end
  local dismissSuggestion
  dismissSuggestion = function()
    if isDisplayingSuggestion() then
      vim.fn["copilot#Dismiss"]()
      return "<esc>"
    else
      return "<esc>"
    end
  end
  vim.keymap.set("i", "<C-]>", "", { })
  vim.keymap.del("i", "<C-]>")
  vim.keymap.set("i", "<M-]>", "", { })
  vim.keymap.del("i", "<M-]>")
  vim.keymap.set("i", "<M-[>", "", { })
  vim.keymap.del("i", "<M-[>")
  vim.keymap.set("i", "<M-\\>", "", { })
  vim.keymap.del("i", "<M-\\>")
  vim.keymap.set("i", "<C-j>", nextSuggestion, {
    script = true
  })
  vim.keymap.set("i", "<C-k>", previousSuggestion, {
    script = true
  })
  return vim.keymap.set("i", "<esc>", dismissSuggestion, {
    script = true,
    expr = true
  })
end
local diagnosticsigns
diagnosticsigns = function()
  local vimLSPProtocol = require("vim.lsp.protocol")
  vimLSPProtocol.CompletionItemKind = {
    "",
    "",
    "ƒ",
    " ",
    "",
    "",
    "",
    "ﰮ",
    "",
    "",
    "",
    "",
    "了",
    " ",
    "﬌ ",
    " ",
    " ",
    "",
    " ",
    " ",
    " ",
    " ",
    "",
    "",
    "<>"
  }
  local signs = {
    Error = " ",
    Warn = " ",
    Hint = " ",
    Info = " "
  }
  for signType, signIcon in pairs(signs) do
    local hl = "DiagnosticSign" .. tostring(signType)
    vim.fn.sign_define(hl, {
      text = signIcon,
      texthl = hl,
      numhl = ""
    })
  end
end
local languageServerProtocol
languageServerProtocol = function()
  local lspkind = require("lspkind")
  lspkind.init({ })
  local cmp = require("cmp")
  lspkind = require("lspkind")
  cmp.setup({
    sorting = {
      priority_weight = 2,
      comparators = {
        cmp.config.compare.offset,
        cmp.config.compare.exact,
        cmp.config.compare.score,
        cmp.config.compare.recently_used,
        cmp.config.compare.locality,
        cmp.config.compare.kind,
        cmp.config.compare.sort_text,
        cmp.config.compare.length,
        cmp.config.compare.order
      }
    },
    formatting = {
      format = lspkind.cmp_format({
        mode = "symbol",
        max_width = 50,
        symbol = { }
      })
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-e>"] = cmp.mapping.abort(),
      ["<CR>"] = cmp.mapping.confirm({
        select = true
      })
    }),
    sources = cmp.config.sources({
      {
        name = "nvim_lsp",
        group_index = 2
      },
      {
        name = "path",
        group_index = 2
      },
      {
        name = "buffer",
        group_index = 2
      }
    })
  })
  cmp.setup.filetype("gitcommit", {
    sources = cmp.config.sources({
      {
        name = "buffer"
      }
    })
  })
  cmp.setup.cmdline({
    "/",
    "?"
  }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      {
        name = "buffer"
      }
    }
  })
  cmp.setup.cmdline(":", {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      {
        name = "path"
      },
      {
        name = "cmdline"
      }
    })
  })
  local whichkey = require("which-key")
  local lspconfig = require("lspconfig")
  local cmpNvimLSP = require("cmp_nvim_lsp")
  local capabilities = cmpNvimLSP.default_capabilities()
  local flags = {
    debounce_text_changes = 150
  }
  vim.keymap.set("n", "K", vim.lsp.buf.hover, {
    noremap = true,
    silent = true
  })
  lspconfig.bashls.setup({
    capabilities = capabilities,
    flags = flags
  })
  lspconfig.cucumber_language_server.setup({
    capabilities = capabilities,
    flags = flags
  })
  lspconfig.cssls.setup({
    capabilities = capabilities,
    flags = flags,
    cmd = {
      "vscode-css-language-server",
      "--stdio"
    },
    filetypes = {
      "css",
      "scss",
      "less"
    },
    init_options = {
      embeddedLanguages = {
        css = true,
        scss = true,
        less = true
      }
    }
  })
  lspconfig.cssmodules_ls.setup({
    capabilities = capabilities,
    flags = flags,
    filetypes = {
      "module.css"
    }
  })
  lspconfig.dockerls.setup({
    capabilities = capabilities,
    cmd = {
      "docker-langserver",
      "--stdio"
    },
    flags = flags
  })
  lspconfig.dotls.setup({
    capabilities = capabilities,
    cmd = {
      "dot-language-server",
      "--stdio"
    },
    flags = flags
  })
  lspconfig.graphql.setup({
    capabilities = capabilities,
    flags = flags,
    cmd = {
      "graphql-lsp",
      "server",
      "-m",
      "stream"
    }
  })
  lspconfig.html.setup({
    capabilities = capabilities,
    flags = flags,
    cmd = {
      "vscode-html-language-server",
      "--stdio"
    }
  })
  lspconfig.jsonls.setup({
    capabilities = capabilities,
    flags = flags
  })
  lspconfig.lua_ls.setup({
    capabilities = capabilities,
    flags = flags,
    cmd = {
      "lua-language-server"
    },
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = vim.split(package.path, ";")
        },
        diagnostics = {
          globals = {
            "vim"
          }
        },
        workspace = {
          library = {
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
          }
        }
      }
    },
    lspconfig.nil_ls.setup({
      capabilities = capabilities,
      flags = flags
    }),
    lspconfig.stylelint_lsp.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "stylelint-lsp",
        "--stdio"
      },
      filetypes = {
        "css",
        "scss",
        "less"
      }
    }),
    lspconfig.tsserver.setup({
      capabilities = capabilities,
      flags = flags
    }),
    lspconfig.vimls.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "vim-language-server",
        "--stdio"
      },
      filetypes = {
        "vim"
      },
      init_options = {
        diagnostic = {
          enable = true
        },
        indexes = {
          count = 3,
          gap = 100,
          projectRootPatterns = {
            "runtime",
            "nvim",
            ".git",
            "autoload",
            "plugin"
          }
        },
        iskeyword = "@,48-57,_,192-255,-#",
        runtimepath = "",
        suggest = {
          fromRuntimepath = true,
          fromVimruntime = true
        },
        vimruntime = ""
      }
    }),
    lspconfig.yamlls.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "yaml-language-server",
        "--stdio"
      },
      filetypes = {
        "yaml"
      },
      init_options = {
        validate = true,
        hover = true,
        completion = true,
        format = {
          enable = true
        }
      }
    }),
    lspconfig.pylsp.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "pylsp"
      },
      filetypes = {
        "python"
      },
      init_options = {
        plugins = {
          jedi_completion = {
            enabled = true
          },
          jedi_hover = {
            enabled = true
          },
          jedi_references = {
            enabled = true
          },
          jedi_signature_help = {
            enabled = true
          },
          jedi_symbols = {
            enabled = true
          },
          jedi_definition = {
            enabled = true
          },
          jedi_document_symbols = {
            enabled = true
          },
          jedi_implementations = {
            enabled = true
          },
          jedi_rename = {
            enabled = true
          },
          jedi_workspace_symbols = {
            enabled = true
          },
          pycodestyle = {
            enabled = true
          },
          pydocstyle = {
            enabled = true
          },
          pyflakes = {
            enabled = true
          },
          pylint = {
            enabled = true
          },
          mccabe = {
            enabled = true
          },
          preload = {
            enabled = true
          },
          rope_completion = {
            enabled = true
          },
          rope_hover = {
            enabled = true
          },
          rope_rename = {
            enabled = true
          },
          rope_references = {
            enabled = true
          },
          rope_signature_help = {
            enabled = true
          },
          rope_symbols = {
            enabled = true
          },
          rope_definition = {
            enabled = true
          },
          rope_document_symbols = {
            enabled = true
          },
          rope_implementations = {
            enabled = true
          },
          rope_workspace_symbols = {
            enabled = true
          }
        }
      }
    }),
    lspconfig.pyright.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "pyright-langserver",
        "--stdio"
      },
      filetypes = {
        "python"
      },
      init_options = {
        analysis = {
          autoImportCompletions = true,
          autoSearchPaths = true,
          diagnosticMode = "workspace",
          useLibraryCodeForTypes = true
        }
      }
    }),
    whichkey.register({
      l = {
        name = "LSP",
        d = {
          vim.lsp.buf.definition,
          "Definition"
        },
        D = {
          vim.lsp.buf.declaration,
          "Declaration"
        },
        h = {
          vim.lsp.buf.hover,
          "Hover"
        },
        i = {
          vim.lsp.buf.implementation,
          "Implementation"
        },
        r = {
          vim.lsp.buf.references,
          "References"
        },
        R = {
          vim.lsp.buf.rename,
          "Rename"
        },
        a = {
          vim.lsp.buf.code_action,
          "Code Action"
        },
        k = {
          vim.lsp.buf.signature_help,
          "Signature Help"
        }
      }
    }, {
      prefix = "<leader>"
    })
  })
  local null_ls = require("null-ls")
  local augroup = vim.api.nvim_create_augroup("LspFormatting", { })
  return null_ls.setup({
    sources = {
      null_ls.builtins.code_actions.eslint_d,
      null_ls.builtins.code_actions.gitrebase,
      null_ls.builtins.code_actions.gitsigns,
      null_ls.builtins.code_actions.refactoring,
      null_ls.builtins.code_actions.shellcheck,
      null_ls.builtins.diagnostics.commitlint,
      null_ls.builtins.diagnostics.eslint_d,
      null_ls.builtins.diagnostics.fish,
      null_ls.builtins.diagnostics.flake8,
      null_ls.builtins.diagnostics.luacheck,
      null_ls.builtins.diagnostics.markdownlint,
      null_ls.builtins.diagnostics.stylelint,
      null_ls.builtins.formatting.alejandra,
      null_ls.builtins.formatting.autopep8,
      null_ls.builtins.formatting.black,
      null_ls.builtins.formatting.eslint_d,
      null_ls.builtins.formatting.lua_format
    },
    on_attach = function(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({
          group = augroup,
          buffer = bufnr
        })
        return vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function()
            return vim.lsp.buf.format({
              bufnr = bufnr,
              filter = function(filterClient)
                return filterClient.name ~= "tsserver" and filterClient.name ~= "copilot"
              end
            })
          end
        })
      end
    end
  })
end
(function()
  vim.opt.completeopt = {
    "menu",
    "menuone",
    "noselect"
  }
  vim.opt.updatetime = 300
  vim.opt.shortmess:append("c")
  astparser()
  completepairs()
  copilot()
  diagnosticsigns()
  return languageServerProtocol()
end)();
(function()
  vim.keymap.set("n", "<leader>d", '"+d', { })
  vim.keymap.set("n", "<leader>y", '"+y', { })
  vim.keymap.set("n", "<leader>p", '"+p', { })
  vim.keymap.set("n", "<leader>D", '"*d', { })
  vim.keymap.set("n", "<leader>Y", '"*y', { })
  vim.keymap.set("n", "<leader>P", '"*p', { })
  vim.keymap.set("v", "<C-v>", '"+p', { })
  vim.keymap.set("v", "<C-c>", '"+y', { })
  vim.keymap.set("v", "<C-x>", '"+d', { })
  return vim.keymap.set("i", "<C-v>", '<esc>"+pi', { })
end)()
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
(function()
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
end)();
(function()
  local bufferline = require("bufferline")
  return bufferline.setup({
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      offsets = {
        filetype = "NvimTree",
        text = "File Explorer",
        highlight = "Directory",
        separator = true
      }
    }
  })
end)();
(function()
  local whichkey = require("which-key")
  local nvimtree = require("nvim-tree")
  nvimtree.setup({
    disable_netrw = true,
    sync_root_with_cwd = true,
    reload_on_bufenter = true,
    sort_by = "case_sensitive",
    view = {
      adaptive_size = true
    },
    renderer = {
      group_empty = true
    },
    filters = {
      dotfiles = false
    }
  })
  vim.keymap.set("n", "<C-t>", ":NvimTreeToggle<cr>|<C-w>p", {
    noremap = true
  })
  return whichkey.register({
    t = {
      name = "Tree",
      t = {
        "<cmd>NvimTreeToggle<cr>",
        "Toggle"
      },
      f = {
        "<cmd>NvimTreeFindFile<cr>",
        "Find File"
      },
      c = {
        "<cmd>NvimTreeCollapseKeepBuffers<cr>",
        "Collapse & Keep Buffers"
      },
      C = {
        "<cmd>NvimTreeCollapse<cr>",
        "Collapse"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)();
(function()
  local foldMode = require("lib.fold-mode")
  local whichkey = require("which-key")
  vim.opt.foldenable = true
  vim.opt.foldignore = ""
  whichkey.register({
    F = {
      name = "Fold",
      c = {
        foldMode.classFoldMode,
        "Class"
      },
      d = {
        foldMode.defaultFoldMode,
        "Default"
      },
      f = {
        foldMode.functionFoldMode,
        "Function"
      }
    }
  }, {
    prefix = "<leader>"
  })
  return foldMode.defaultFoldMode()
end)();
(function() end)()
local whichkey = require('which-key')
whichkey.setup({ })
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = ' ';
(function()
  vim.opt.number = true
  vim.opt.relativenumber = true
end)()
local mouse
mouse = function()
  vim.opt.mouse = "a"
end
local comment
comment = function()
  local nvimComment = require("nvim_comment")
  nvimComment.setup()
  vim.keymap.set("n", "<C-_>", ":CommentToggle<cr>", {
    noremap = true
  })
  vim.keymap.set("n", "<C-/>", ":CommentToggle<cr>", {
    noremap = true
  })
  vim.keymap.set("v", "<C-_>", ":\"<,\">CommentToggle<cr>", {
    noremap = true
  })
  return vim.keymap.set("v", "<C-/>", ":\"<,\">CommentToggle<cr>", {
    noremap = true
  })
end
(function()
  vim.opt.whichwrap = "b,s,h,l,<,>,[,]"
  vim.opt.backspace = "indent,eol,start"
  vim.opt.scrolloff = 50
  mouse()
  return comment()
end)();
(function()
  whichkey = require("which-key")
  local trouble = require("trouble")
  trouble.setup({
    auto_open = false,
    auto_close = false,
    auto_preview = true,
    use_diagnostic_signs = true
  })
  return whichkey.register({
    x = {
      name = "Quickfix",
      x = {
        "<cmd>TroubleToggle<cr>",
        "Toggle"
      },
      w = {
        "<cmd>TroubleToggle workspace_diagnostics<cr>",
        "Workspace"
      },
      d = {
        "<cmd>TroubleToggle document_diagnostics<cr>",
        "Document"
      },
      l = {
        "<cmd>TroubleToggle loclist<cr>",
        "Loclist"
      },
      q = {
        "<cmd>TroubleToggle quickfix<cr>",
        "Quickfix"
      },
      R = {
        "<cmd>TroubleToggle lsp_references<cr>",
        "References"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)()
local indentationGuides
indentationGuides = function()
  local indentBlankline = require("indent_blankline")
  return indentBlankline.setup({
    show_current_context = true,
    show_current_context_start = true
  })
end
(function()
  vim.keymap.set("n", "<C-s>", ":write<cr>", { })
  vim.keymap.set("i", "<C-s>", "<esc>:write<cr>a", { })
  return indentationGuides()
end)()
local bufferSearch
bufferSearch = function()
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.hlsearch = true
  vim.opt.incsearch = true
end
local findModalDialog
findModalDialog = function()
  local telescope = require("telescope")
  local telescopeBuiltin = require("telescope.builtin")
  whichkey = require("which-key")
  telescope.setup({ })
  local findFiles
  findFiles = function()
    return telescopeBuiltin.find_files({
      hidden = true
    })
  end
  vim.keymap.set("n", "<C-p>", findFiles, {
    noremap = true
  })
  return whichkey.register({
    f = {
      name = "Find",
      C = {
        telescopeBuiltin.command_history,
        "command history"
      },
      ["/"] = {
        telescopeBuiltin.current_buffer_fuzzy_find,
        "in buffer"
      },
      b = {
        telescopeBuiltin.buffers,
        "buffers"
      },
      c = {
        telescopeBuiltin.commands,
        "commands"
      },
      g = {
        name = "Git",
        b = {
          telescopeBuiltin.git_branches,
          "branches"
        },
        c = {
          telescopeBuiltin.git_commits,
          "commits"
        },
        d = {
          telescopeBuiltin.git_bcommits,
          "diff"
        },
        s = {
          telescopeBuiltin.git_status,
          "status"
        },
        t = {
          telescopeBuiltin.git_stash,
          "stash"
        }
      },
      f = {
        telescopeBuiltin.live_grep,
        "in files"
      },
      h = {
        telescopeBuiltin.help_tags,
        "help tags"
      },
      p = {
        findFiles,
        "files"
      },
      q = {
        telescopeBuiltin.quickfix,
        "quickfix"
      },
      r = {
        telescopeBuiltin.registers,
        "registers"
      },
      l = {
        name = "LSP",
        a = {
          telescopeBuiltin.lsp_code_actions,
          "code actions"
        },
        d = {
          telescopeBuiltin.lsp_definitions,
          "definitions"
        },
        t = {
          telescopeBuiltin.lsp_type_definitions,
          "type definitions"
        },
        i = {
          telescopeBuiltin.lsp_implementations,
          "implementations"
        },
        r = {
          telescopeBuiltin.lsp_references,
          "references"
        },
        s = {
          telescopeBuiltin.lsp_document_symbols,
          "document symbols"
        },
        w = {
          telescopeBuiltin.lsp_workspace_symbols,
          "workspace symbols"
        }
      }
    }
  }, {
    prefix = "<leader>"
  })
end
(function()
  bufferSearch()
  return findModalDialog()
end)();
(function()
  whichkey = require("which-key")
  vim.opt.splitbelow = true
  vim.opt.splitright = true
  vim.keymap.set("n", "<C-h>", "<C-w>h", {
    noremap = true
  })
  vim.keymap.set("n", "<C-j>", "<C-w>j", {
    noremap = true
  })
  vim.keymap.set("n", "<C-k>", "<C-w>k", {
    noremap = true
  })
  vim.keymap.set("n", "<C-l>", "<C-w>l", {
    noremap = true
  })
  return whichkey.register({
    w = {
      name = "Window",
      c = {
        "<C-W>c",
        "Close"
      },
      h = {
        "<C-W>h",
        "Left"
      },
      H = {
        "<C-W>5>",
        "Left (Resize)"
      },
      j = {
        "<C-W>j",
        "Down"
      },
      J = {
        ":resize +5",
        "Down (Resize)"
      },
      k = {
        "<C-W>k",
        "Up"
      },
      K = {
        ":resize -5",
        "Up (Resize)"
      },
      l = {
        "<C-W>l",
        "Right"
      },
      L = {
        "<C-W>5<",
        "Right (Resize)"
      },
      ["="] = {
        "<C-W>=",
        "Balance"
      },
      s = {
        "<C-W>s",
        "Horizontal"
      },
      ["-"] = {
        "<C-W>s",
        "Horizontal"
      },
      v = {
        "<C-W>v",
        "Vertical"
      },
      ["|"] = {
        "<C-W>v",
        "Vertical"
      }
    }
  }, {
    prefix = "<leader>"
  })
end)();
(function()
  local lualine = require("lualine")
  return lualine.setup({
    options = {
      icons_enabled = true,
      theme = "auto",
      component_separators = {
        left = "",
        right = ""
      },
      section_separators = {
        left = "",
        right = ""
      },
      disabled_filetypes = {
        statusline = { },
        winbar = { }
      },
      ignore_focus = { },
      always_divide_middle = true,
      globalstatus = false,
      refresh = {
        statusline = 1000,
        tabline = 1000,
        winbar = 1000
      }
    },
    sections = {
      lualine_a = {
        "mode"
      },
      lualine_b = {
        "branch",
        "diff",
        "diagnostics"
      },
      lualine_c = {
        "filename"
      },
      lualine_x = {
        "encoding",
        "fileformat",
        "filetype"
      },
      lualine_y = {
        "progress"
      },
      lualine_z = {
        "location"
      }
    },
    inactive_sections = {
      lualine_a = { },
      lualine_b = { },
      lualine_c = {
        "filename"
      },
      lualine_x = {
        "location"
      },
      lualine_y = { },
      lualine_z = { }
    }
  })
end)()
local highlightCursorLine
highlightCursorLine = function()
  vim.opt.cursorline = true
  vim.opt.cursorcolumn = false
end
return (function()
  vim.opt.signcolumn = "auto"
  return highlightCursorLine()
end)()
