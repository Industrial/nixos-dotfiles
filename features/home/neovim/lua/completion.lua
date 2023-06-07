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
    lspconfig.purescriptls.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "purescript-language-server",
        "--stdio"
      },
      filetypes = {
        "purescript"
      },
      settings = {
        purescript = {
          addSpagoSources = true,
          addNpmPath = true,
          formatter = "purs-tidy"
        }
      }
    }),
    (function()
      vim.g.purescript_disable_indent = 1
      vim.g.purescript_unicode_conceal_enable = 1
      vim.g.purescript_unicode_conceal_disable_common = 0
      vim.g.purescript_unicode_conceal_enable_discretionary = 1
    end)(),
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
      null_ls.builtins.code_actions.statix,
      null_ls.builtins.diagnostics.commitlint,
      null_ls.builtins.diagnostics.eslint_d,
      null_ls.builtins.diagnostics.fish,
      null_ls.builtins.diagnostics.flake8,
      null_ls.builtins.diagnostics.luacheck,
      null_ls.builtins.diagnostics.statix,
      null_ls.builtins.diagnostics.tsc,
      null_ls.builtins.formatting.alejandra,
      null_ls.builtins.formatting.autopep8,
      null_ls.builtins.formatting.black,
      null_ls.builtins.formatting.eslint_d,
      null_ls.builtins.formatting.lua_format,
      null_ls.builtins.formatting.purs_tidy
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
return (function()
  vim.opt.completeopt = {
    "menu",
    "menuone",
    "noselect"
  }
  vim.opt.updatetime = 300
  vim.opt.shortmess:append("c")
  astparser()
  completepairs()
  diagnosticsigns()
  return languageServerProtocol()
end)()
