astparser = () ->
  nvimTreeSitterConfigs = require "nvim-treesitter.configs"

  vim.opt.runtimepath\append "/home/tom/.config/nvim/treesitter_parsers"

  nvimTreeSitterConfigs.setup {
    parser_install_dir: "/home/tom/.config/nvim/treesitter_parsers"
    ensure_installed: "all"
    sync_install: false
    auto_install: true
    highlight:
      enable: true
      additional_vim_regex_highlighting: false
    autotag:
      enable: true
    rainbow:
      enable: true
      extended_mode: false
      max_file_lines: nil
    autopairs:
      enable: true
  }

completepairs = () ->
  nvimAutoPairs = require "nvim-autopairs"
  nvimAutoPairs.setup {}

copilot = () ->
  vim.g.copilot_enabled = true
  vim.g.copilot_filetypes =
    "*": true

  -- When I turn off mappings by using these options, automatic
  -- completion stops working, so turn the mappings off manually.
  -- Set the maps first to ensure that they exist before trying
  -- to unmap them when reloading the config.
  -- vim.g.copilot_no_maps = true
  -- vim.g.copilot_no_tab_map = true

  isDisplayingSuggestion = () ->
    displayedSuggestion = vim.fn["copilot#GetDisplayedSuggestion"]!
    displayedSuggestion and string.len(displayedSuggestion.text) > 0

  nextSuggestion = () ->
    if isDisplayingSuggestion! then
      vim.fn["copilot#Next"]!
    else
      vim.fn["copilot#Suggest"]!

  previousSuggestion = () ->
    vim.fn["copilot#Previous"]!

  dismissSuggestion = () ->
    if isDisplayingSuggestion! then
      vim.fn["copilot#Dismiss"]!
      "<esc>"
    else
      "<esc>"

  -- Unset default keybindings.
  vim.keymap.set "i", "<C-]>", "", {}
  vim.keymap.del "i", "<C-]>"

  vim.keymap.set "i", "<M-]>", "", {}
  vim.keymap.del "i", "<M-]>"

  vim.keymap.set "i", "<M-[>", "", {}
  vim.keymap.del "i", "<M-[>"

  vim.keymap.set "i", "<M-\\>", "", {}
  vim.keymap.del "i", "<M-\\>"

  vim.keymap.set "i", "<C-j>", nextSuggestion, {
    script: true
  }

  vim.keymap.set "i", "<C-k>", previousSuggestion, {
    script: true
  }

  vim.keymap.set "i", "<esc>", dismissSuggestion, {
    script: true
    expr: true
  }

  -- vim.defer_fn configure, 100

diagnosticsigns = () ->
  vimLSPProtocol = require "vim.lsp.protocol"

  -- icons
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
    "<>",
  }

  -- Diagnostic Signs
  signs = {
    Error: " "
    Warn: " "
    Hint: " "
    Info: " "
  }

  for signType, signIcon in pairs(signs) do
    hl = "DiagnosticSign#{signType}"
    vim.fn.sign_define hl,
      text: signIcon
      texthl: hl
      numhl: ""

languageServerProtocol = () ->
  lspkind = require "lspkind"
  lspkind.init {}

  cmp = require "cmp"
  lspkind = require "lspkind"
  cmp.setup {
    sorting:
      priority_weight: 2
      comparators: {
        cmp.config.compare.offset,
        cmp.config.compare.exact,
        cmp.config.compare.score,
        cmp.config.compare.recently_used,
        cmp.config.compare.locality,
        cmp.config.compare.kind,
        cmp.config.compare.sort_text,
        cmp.config.compare.length,
        cmp.config.compare.order,
      }

    formatting:
      format: lspkind.cmp_format
        mode: "symbol"
        max_width: 50
        symbol: {}

    mapping: cmp.mapping.preset.insert {
      "<C-b>": cmp.mapping.scroll_docs -4
      "<C-f>": cmp.mapping.scroll_docs 4
      "<C-Space>": cmp.mapping.complete!
      "<C-e>": cmp.mapping.abort!
      "<CR>": cmp.mapping.confirm {
        select: true
      }
    }

    sources: cmp.config.sources {
      {
        name: "nvim_lsp"
        group_index: 2
      },
      {
        name: "path"
        group_index: 2
      },
      {
        name: "buffer"
        group_index: 2
      }
    }
  }

  -- Set configuration for specific filetype.
  cmp.setup.filetype "gitcommit",
    sources: cmp.config.sources {
      {
        name: "buffer"
      }
    }

  -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won"t work anymore).
  cmp.setup.cmdline { "/", "?" },
    mapping: cmp.mapping.preset.cmdline!
    sources: {
      { name: "buffer" }
    }

  -- Use cmdline & path source for ":" (if you enabled `native_menu`, this won"t work anymore).
  cmp.setup.cmdline ":",
    mapping: cmp.mapping.preset.cmdline!
    sources: cmp.config.sources {
      {
        name: "path"
      }
      {
        name: "cmdline"
      }
    }

  whichkey = require "which-key"
  lspconfig = require "lspconfig"
  cmpNvimLSP = require "cmp_nvim_lsp"
  capabilities = cmpNvimLSP.default_capabilities!
  flags = {
    debounce_text_changes: 150
  }

  vim.keymap.set "n", "K", vim.lsp.buf.hover, {
    noremap: true
    silent: true
  }

  -- Bash
  lspconfig.bashls.setup {
    capabilities: capabilities
    flags: flags
  }

  -- Cucumber
  lspconfig.cucumber_language_server.setup {
    capabilities: capabilities
    flags: flags
  }

  -- CSS
  lspconfig.cssls.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "vscode-css-language-server", "--stdio" }
    filetypes: { "css", "scss", "less" }
    init_options:
      embeddedLanguages:
        css: true
        scss: true
        less: true
  }
    
  -- CSS Modules
  lspconfig.cssmodules_ls.setup {
    capabilities: capabilities
    flags: flags
    filetypes: { "module.css" }
  }

  -- Docker
  lspconfig.dockerls.setup {
    capabilities: capabilities
    cmd: { "docker-langserver", "--stdio" }
    flags: flags
  }

  -- Dot
  lspconfig.dotls.setup {
    capabilities: capabilities
    cmd: { "dot-language-server", "--stdio" }
    flags: flags
  }

  -- GraphQL
  lspconfig.graphql.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "graphql-lsp", "server", "-m", "stream" }
  }

  -- HTML
  lspconfig.html.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "vscode-html-language-server", "--stdio" }
  }

  -- JSON
  lspconfig.jsonls.setup {
    capabilities: capabilities
    flags: flags
    -- commands:
    --   Format: () ->
    --     vim.lsp.buf.range_formatting {}, { 0, 0 }, { (vim.fn.line "$"), 0 }
  }

  -- Lua
  lspconfig.lua_ls.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "lua-language-server" }
    settings:
      Lua:
        runtime:
          version: "LuaJIT",
          path: vim.split package.path, ";"
        diagnostics:
          globals: { "vim" }
        workspace:
          library: {
            [vim.fn.expand "$VIMRUNTIME/lua"]: true
            [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"]: true
          }

  -- Nix
  lspconfig.nil_ls.setup {
    capabilities: capabilities
    flags: flags
  }

  -- StyleLint
  lspconfig.stylelint_lsp.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "stylelint-lsp", "--stdio" }
    filetypes: { "css", "scss", "less" }
  }

  -- TypeScript
  lspconfig.tsserver.setup {
    capabilities: capabilities
    flags: flags
  }

  -- Vim
  lspconfig.vimls.setup {
    capabilities: capabilities,
    flags: flags
    cmd: { "vim-language-server", "--stdio" }
    filetypes: { "vim" }
    init_options:
      diagnostic:
        enable: true
      indexes:
        count: 3
        gap: 100
        projectRootPatterns: { "runtime", "nvim", ".git", "autoload", "plugin" }
      iskeyword: "@,48-57,_,192-255,-#"
      runtimepath: ""
      suggest:
        fromRuntimepath: true
        fromVimruntime: true
      vimruntime: ""
  }

  -- YAML
  lspconfig.yamlls.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "yaml-language-server", "--stdio" }
    filetypes: { "yaml" }
    init_options:
      validate: true
      hover: true
      completion: true
      format:
        enable: true
  }

  -- pylsp
  lspconfig.pylsp.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "pylsp" }
    filetypes: { "python" }
    init_options:
      plugins:
        jedi_completion:
          enabled: true
        jedi_hover:
          enabled: true
        jedi_references:
          enabled: true
        jedi_signature_help:
          enabled: true
        jedi_symbols:
          enabled: true
        jedi_definition:
          enabled: true
        jedi_document_symbols:
          enabled: true
        jedi_implementations:
          enabled: true
        jedi_rename:
          enabled: true
        jedi_workspace_symbols:
          enabled: true
        pycodestyle:
          enabled: true
        pydocstyle:
          enabled: true
        pyflakes:
          enabled: true
        pylint:
          enabled: true
        mccabe:
          enabled: true
        preload:
          enabled: true
        rope_completion:
          enabled: true
        rope_hover:
          enabled: true
        rope_rename:
          enabled: true
        rope_references:
          enabled: true
        rope_signature_help:
          enabled: true
        rope_symbols:
          enabled: true
        rope_definition:
          enabled: true
        rope_document_symbols:
          enabled: true
        rope_implementations:
          enabled: true
        rope_workspace_symbols:
          enabled: true
  }

  -- pyright
  lspconfig.pyright.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "pyright-langserver", "--stdio" }
    filetypes: { "python" }
    init_options:
      analysis:
        autoImportCompletions: true
        autoSearchPaths: true
        diagnosticMode: "workspace"
        useLibraryCodeForTypes: true
  }

  -- PureScript
  lspconfig.purescriptls.setup {
    capabilities: capabilities
    flags: flags
    cmd: { "purescript-language-server", "--stdio" }
    filetypes: { "purescript" }
    settings:
      purescript:
        addSpagoSources: true
        addNpmPath: true
        formatter: "purs-tidy"
  }
  -- TODO: Couldn't get this to parse unless it was in a function.
  (() ->
    vim.g.purescript_disable_indent = 1
    vim.g.purescript_unicode_conceal_enable = 1
    vim.g.purescript_unicode_conceal_disable_common = 0
    vim.g.purescript_unicode_conceal_enable_discretionary = 1
  )!

  whichkey.register {
    l:
      name: "LSP"
      d: { vim.lsp.buf.definition, "Definition" }
      D: { vim.lsp.buf.declaration, "Declaration" }
      h: { vim.lsp.buf.hover, "Hover" }
      i: { vim.lsp.buf.implementation, "Implementation" }
      r: { vim.lsp.buf.references, "References" }
      R: { vim.lsp.buf.rename, "Rename" }
      a: { vim.lsp.buf.code_action, "Code Action" }
      k: { vim.lsp.buf.signature_help, "Signature Help" }
    }, {
      prefix: "<leader>"
    }
  }

  -- TODO: add refactoring.nvim to nixos
  -- TODO: add gitsigns.nvim to nixos
  null_ls = require "null-ls"
  augroup = vim.api.nvim_create_augroup "LspFormatting", {}
  null_ls.setup {
    sources: {
      -- null_ls.builtins.completion.spell,
      -- null_ls.builtins.formatting.codespell,
      -- null_ls.builtins.diagnostics.codespell,
      -- null_ls.builtins.formatting.luacheck,
      -- null_ls.builtins.formatting.stylelint,
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
      null_ls.builtins.formatting.lua_format,

      -- Using Alejandra instead.
      --null_ls.builtins.formatting.nixfmt,
    }
    on_attach: (client, bufnr) ->
      -- Format on save (not async, safer)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds {
          group: augroup
          buffer: bufnr
        }
        vim.api.nvim_create_autocmd "BufWritePre", {
          group: augroup,
          buffer: bufnr,
          callback: () ->
            vim.lsp.buf.format {
              bufnr: bufnr,
              filter: (filterClient) ->
                filterClient.name ~= "tsserver" and filterClient.name ~= "copilot"
            }
        }
  }

(() ->
  -- TODO: Document.
  vim.opt.completeopt = {
    "menu",
    "menuone",
    "noselect",
  }

  -- TODO: Document.
  vim.opt.updatetime = 300

  -- TODO: Document.
  vim.opt.shortmess\append "c"

  astparser!
  completepairs!
  --copilot!
  diagnosticsigns!
  languageServerProtocol!
)!
