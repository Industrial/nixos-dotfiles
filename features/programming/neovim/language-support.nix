{pkgs,...}: {
  environment.systemPackages = with pkgs; [
    # nodePackages.cssmodules-language-server
    # nodePackages.dot-language-server
    alejandra
    eslint_d
    lua-language-server
    luaPackages.luacheck
    nixd
    nodePackages.bash-language-server
    nodePackages.dockerfile-language-server-nodejs
    nodePackages.eslint
    nodePackages.graphql-language-service-cli
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.vim-language-server
    nodePackages.vscode-langservers-extracted
    python311Packages.autopep8
    python311Packages.flake8
    shellcheck
    statix
  ];

  # - Languages
  # https://github.com/mfussenegger/nvim-lint
  programs.nixvim.plugins.lint.enable = true;
  programs.nixvim.plugins.nix.enable = true;
  programs.nixvim.plugins.treesitter.enable = true;
  programs.nixvim.plugins.treesitter.indent = true;
  programs.nixvim.plugins.hmts.enable = true;
  programs.nixvim.plugins.rainbow-delimiters.enable = true;
  programs.nixvim.plugins.treesitter-context.enable = true;
  programs.nixvim.plugins.treesitter-refactor.enable = true;
  programs.nixvim.plugins.ts-autotag.enable = true;
  programs.nixvim.plugins.ts-context-commentstring.enable = true;
  programs.nixvim.plugins.direnv.enable = true;

  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
    lspkind-nvim
    nvim-lspconfig
  ];
  programs.nixvim.plugins.none-ls.enable = true;
  programs.nixvim.plugins.cmp.enable = true;
  programs.nixvim.plugins.cmp-nvim-lsp.enable = true;
  programs.nixvim.plugins.cmp-buffer.enable = true;
  programs.nixvim.plugins.cmp-path.enable = true;
  programs.nixvim.plugins.cmp-cmdline.enable = true;
  programs.nixvim.plugins.copilot-cmp.enable = true;

  programs.nixvim.extraConfigLua = ''
    local cmp = require('cmp')
    local cmpNvimLSP = require('cmp_nvim_lsp')
    local copilot = require('copilot')
    local copilotCMP = require('copilot_cmp')
    local lspconfig = require('lspconfig')
    local lspkind = require('lspkind')
    --local whichkey = require('whichkey')

    cmp.setup({
      priority_weight = 2,
      sorting = {
        comparators = {
          cmp.config.compare.offset,
          cmp.config.compare.exact,
          cmp.config.compare.score,
          cmp.config.compare.recently_used,
          cmp.config.compare.locality,
          cmp.config.compare.kind,
          cmp.config.compare.sort_text,
          cmp.config.compare.length,
          cmp.config.compare.order,
        },
      },
      formatting = {
        format = lspkind.cmp_format({
          mode = "symbol",
          max_widt = 50,
          symbol_map = {
            Copilot = "",
          },
        }),
      },
      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },
      mapping = cmp.mapping.preset.insert({
        ['<esc>'] = cmp.mapping.abort(),
        ['<cr>'] = cmp.mapping.confirm({ select = true }),
        ['<tab>'] = cmp.mapping.confirm({ select = true }),
      }),
      sources = cmp.config.sources({
        {
          name = 'copilot',
          group_index = 2,
        },
        {
          name = 'nvim_lsp',
          group_index = 2,
        },
        {
          name = 'path',
          group_index = 2,
        },
        {
          name = 'buffer',
          group_index = 2,
        },
        -- { name = 'vsnip' }, -- For vsnip users.
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

    local capabilities = cmpNvimLSP.default_capabilities()
    local flags = {
      debounce_text_changes = 150
    }
    vim.keymap.set("n", "<S-k>", vim.lsp.buf.hover, {
      noremap = true,
      silent = true
    })

    -- Azure Pipelines
    lspconfig.azure_pipelines_ls.setup({
      settings = {
        yaml = {
          schemas = {
            ["https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json"] = {
              "/azure-pipeline*.y*l",
              "/*.azure*",
              "Azure-Pipelines/**/*.y*l",
              "Pipelines/*.y*l",
            },
          },
        },
      },
    })

    -- Bash
    lspconfig.bashls.setup({
      capabilities = capabilities,
      flags = flags
    })

    -- CSS
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

    -- Docker
    lspconfig.dockerls.setup({
      capabilities = capabilities,
      cmd = {
        "docker-langserver",
        "--stdio"
      },
      flags = flags
    })

    -- Dot
    lspconfig.dotls.setup({
      capabilities = capabilities,
      cmd = {
        "dot-language-server",
        "--stdio"
      },
      flags = flags
    })

    -- ESLint
    lspconfig.eslint.setup({
      capabilities = capabilities,
      flags = flags,
      on_attach = function(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          command = "EslintFixAll",
        })
      end,
    })

    -- GraphQL
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

    -- HTML
    lspconfig.html.setup({
      capabilities = capabilities,
      flags = flags,
      cmd = {
        "vscode-html-language-server",
        "--stdio"
      }
    })

    -- JSON
    lspconfig.jsonls.setup({
      capabilities = capabilities,
      flags = flags
    })

    -- Lua
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
    })

    -- Nix
    lspconfig.nixd.setup({
      capabilities = capabilities,
      flags = flags
    })

    -- Python
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
    })
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
    })

    -- TypeScript
    lspconfig.tsserver.setup({
      capabilities = capabilities,
      flags = flags
    })

    -- VimLS
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
    })

    -- YAML
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
    })

    -- lspconfig.denols.setup({ }),
    --whichkey.register({
    --  l = {
    --    name = "LSP",
    --    d = {
    --      vim.lsp.buf.definition,
    --      "Definition"
    --    },
    --    D = {
    --      vim.lsp.buf.declaration,
    --      "Declaration"
    --    },
    --    h = {
    --      vim.lsp.buf.hover,
    --      "Hover"
    --    },
    --    i = {
    --      vim.lsp.buf.implementation,
    --      "Implementation"
    --    },
    --    r = {
    --      vim.lsp.buf.references,
    --      "References"
    --    },
    --    R = {
    --      vim.lsp.buf.rename,
    --      "Rename"
    --    },
    --    a = {
    --      vim.lsp.buf.code_action,
    --      "Code Action"
    --    },
    --    k = {
    --      vim.lsp.buf.signature_help,
    --      "Signature Help"
    --    }
    --  }
    --}, {
    --  prefix = "<leader>"
    --})

    local capabilities = cmpNvimLSP.default_capabilities()
    -- lspconfig['SOMETHING'].setup({
    --   capabilities = capabilities,
    -- })

    lspkind.init({
      mode = 'symbol_text',
    })

    vim.keymap.set("n", "<C-O>", vim.lsp.buf.code_action, { })
    local none_ls = require("null-ls")
    local augroup = vim.api.nvim_create_augroup("LspFormatting", { })
    none_ls.setup({
      sources = {
        -- none_ls.builtins.code_actions.eslint,
        none_ls.builtins.code_actions.gitrebase,
        none_ls.builtins.code_actions.refactoring,
        -- none_ls.builtins.code_actions.shellcheck,
        none_ls.builtins.code_actions.statix,
        none_ls.builtins.diagnostics.commitlint,
        -- none_ls.builtins.diagnostics.eslint,
        none_ls.builtins.diagnostics.fish,
        -- none_ls.builtins.diagnostics.flake8,
        -- none_ls.builtins.diagnostics.luacheck,
        none_ls.builtins.diagnostics.statix,
        -- none_ls.builtins.diagnostics.tsc,
        none_ls.builtins.formatting.alejandra,
        -- none_ls.builtins.formatting.autopep8,
        none_ls.builtins.formatting.black,
        -- none_ls.builtins.formatting.eslint,
        -- none_ls.builtins.formatting.lua_format,
        -- none_ls.builtins.formatting.purs_tidy
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
                  return filterClient.name ~= "tsserver"
                end
              })
            end
          })
        end
      end
    })

    copilot.setup({
      panel = {
        enabled = false,
        auto_refresh = true,
      },
      suggestion = {
        enabled = false,
        auto_trigger = true,
      }
    })
    cmp.event:on('menu_opened', function()
      vim.b.copilot_suggestion_hidden = true
    end)
    cmp.event:on('menu_closed', function()
      vim.b.copilot_suggestion_hidden = false
    end)
    copilotCMP.setup()
  '';
}
