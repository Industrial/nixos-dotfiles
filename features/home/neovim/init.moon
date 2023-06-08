smartBufferDelete = () ->
  lastBuffer = vim.fn.bufnr('%')
  vim.cmd "bnext"
  vim.cmd "bdelete #{lastBuffer}"

smartBufferWipeout = () ->
  lastBuffer = vim.fn.bufnr('%')
  vim.cmd "bnext"
  vim.cmd "bwipeout #{lastBuffer}"

defaultFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'manual'

  -- Remove all folds made by the other fold method.
  vim.cmd('normal zE<cr>')

  -- Set the fold level to 0.
  vim.opt.foldlevelstart = 0

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = -1

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 20

  -- Allow one line folds.
  vim.opt.foldminlines = 1

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '1'

classFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'indent'

  -- Set the fold level to 1.
  vim.opt.foldlevel = 1

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = 1

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 2

  -- Allow one line folds.
  vim.opt.foldminlines = 0

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '3'

functionFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'indent'

  -- Set the fold level to 0.
  vim.opt.foldlevel = 0

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = 0

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 1

  -- Allow one line folds.
  vim.opt.foldminlines = 0

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '1'

backupFiles = () ->
  -- Make backups..
  vim.opt.backup = true

  -- Make a backup before overwriting a file.
  vim.opt.writebackup = true

  -- Directory to keep backup files in.
  vim.opt.backupdir = vim.fn.expand "~/.config/nvim/backup"

  -- When writing a file and a backup is made, make a copy of the file and overwrite the original.
  vim.opt.backupcopy = "yes"

swapFiles = () ->
  -- Use swap files.
  vim.opt.swapfile = true

  -- Directory to put swap files in.
  vim.opt.directory = vim.fn.expand "~/.config/nvim/temp"

undoFiles = () ->
  -- Use undo files.
  vim.opt.undofile = true

  -- Directory to put undo files in.
  vim.opt.undodir = vim.fn.expand "~/.config/nvim/undo"

buffers = () ->
  whichkey = require "which-key"

  -- load filetype plugins, indentation and turn syntax highlighting on
  vim.cmd "filetype plugin indent on"

  -- Buffers in the background.
  vim.opt.hidden = true

  -- don't wrap lines
  vim.opt.wrap = false

  vim.keymap.set "n", "<Tab>", ":BufferLineCycleNext<cr>", {}
  vim.keymap.set "n", "<S-Tab>", ":BufferLineCyclePrev<cr>", {}

  vim.keymap.set "n", "<C-Q>", smartBufferWipeout, {
    noremap: true,
  }

  whichkey.register {
    b:
      name: "Buffers",
      b: { "<cmd>Telescope buffers<cr>", "Buffers" },
      d: { smartBufferDelete, "Delete" },
      w: { smartBufferWipeout, "Wipeout" },
      n: { "<cmd>BufferLineCycleNext<cr>", "Next" },
      p: { "<cmd>BufferLineCyclePrev<cr>", "Previous" },
  }, {
    prefix: "<leader>"
  }

colorscheme = () ->
  vim.g.base16colorspace = 256
  vim.opt.termguicolors = true

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

  -- TODO: gitsigns executable
  -- TODO: shellcheck executable
  -- TODO: commitlint executable
  -- TODO: flake8 executable
  -- TODO: markdownlint executable
  -- TODO: autopep8 executable
  -- TODO: black executable
  -- TODO: lua-format executable

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
      null_ls.builtins.formatting.purs_tidy,

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
                filterClient.name ~= "tsserver"
            }
        }
  }

completion = () ->
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
  diagnosticsigns!
  languageServerProtocol!

copypaste = () ->
  -- Global copy/paste register delete/yank/paste in normal mode.
  vim.keymap.set "n", "<leader>d", '"+d', {}
  vim.keymap.set "n", "<leader>y", '"+y', {}
  vim.keymap.set "n", "<leader>p", '"+p', {}

  -- Mouse copy/paste register delete/yank/paste in normal mode.
  vim.keymap.set "n", "<leader>D", '"*d', {}
  vim.keymap.set "n", "<leader>Y", '"*y', {}
  vim.keymap.set "n", "<leader>P", '"*p', {}

  -- Global copy/paste register delete/yank/paste in visual mode.
  vim.keymap.set "v", "<C-v>", '"+p', {}
  vim.keymap.set "v", "<C-c>", '"+y', {}
  vim.keymap.set "v", "<C-x>", '"+d', {}
  -- Paste from Global Copy/Paste Register in Insert Mode.
  vim.keymap.set "i", "<C-v>", '<esc>"+pi', {}

-- lua = () ->
--   -- TODO: Can't find this package on https://search.nixos.org
--   -- use {
--   --   "jbyuki/one-small-step-for-vimkind",
--   --   config: () ->
--   dap = require "dap"
-- 
--   dap.configurations.lua = {
--     {
--       type: "nlua"
--       request: "attach"
--       name: "Attach to running Neovim instance"
--     }
--   }
-- 
--   dap.adapters.nlua = (callback, config) ->
--     callback {
--       type: "server"
--       host: config.host or "127.0.0.1"
--       port: config.port or 8086
--     }
-- 
-- python = () ->
--   dapPython = require "dap-python"
--   dapPython.setup "~/.virtualenvs/debugpy/bin/python"
-- 
-- nodejs = () ->
--   -- TODO: can't find this package on https://search.nixos.org
--   --   "mxsdev/nvim-dap-vscode-js"
--   dap = require "dap"
--   dapVscodeJs = require "dap-vscode-js"
-- 
--   dapVscodeJs.setup {
--     adapters: {
--       "pwa-node"
--       "pwa-chrome"
--       "pwa-msedge"
--       "node-terminal"
--       "pwa-extensionHost"
--     }
--   }
-- 
--   for _, language in ipairs { "typescript", "javascript" } do
--     dap.configurations[language] = {
--       {
--         type: "pwa-node"
--         request: "launch"
--         name: "Launch file"
--         program: "${file}"
--         cwd: "${workspaceFolder}"
--       },
--       {
--         type: "pwa-node"
--         request: "attach"
--         name: "Attach"
--         processId: require"dap.utils".pick_process
--         cwd: "${workspaceFolder}"
--       },
--       {
--         type: "pwa-node"
--         request: "launch"
--         name: "Debug Jest Tests"
--         -- trace: true, -- include debugger info
--         runtimeExecutable: "node"
--         runtimeArgs: {
--           "./node_modules/jest/bin/jest.js"
--           "--runInBand"
--         },
--         rootPath: "${workspaceFolder}"
--         cwd: "${workspaceFolder}"
--         console: "integratedTerminal"
--         internalConsoleOptions: "neverOpen"
--       }
--     }
-- 
--   -- TODO: can't find this package on https://search.nixos.org
--   --   "microsoft/vscode-js-debug"
-- 
-- interface = () ->
--   dapui = require "dapui"
-- 
--   dapui.setup!
-- 
-- debugger = () ->
--   whichkey = require "which-key"
--   dapui = require "dapui"
-- 
--   whichkey.register {
--     d:
--       name: "Debug"
--       d: { dapui.toggle, "Toggle DAP UI" }
--       c: { "<cmd>DapContinue<cr>", "Continue" }
--       s: { "<cmd>DapTerminate<cr>", "Stop" }
--       b: { "<cmd>DapToggleBreakpoint<cr>", "Breakpoint" }
--       r: { "<cmd>DapRestartFrame<cr>", "Breakpoint" }
--       j: { "<cmd>DapStepOver<cr>", "Step Over" }
--       J: { "<cmd>DapStepInto<cr>", "Step Into" }
--       K: { "<cmd>DapStepOut<cr>", "Step Out" }
--   }, {
--     prefix: "<leader>"
--   }
-- 
--   interface!
--   lua!
--   python!

filetabs = () ->
  bufferline = require "bufferline"

  bufferline.setup {
    options:
      mode: "buffers"
      diagnostics: "nvim_lsp"
      offsets:
        {
          filetype: "NvimTree"
          text: "File Explorer"
          highlight: "Directory"
          separator: true
        }
  }

filetreesidebar = () ->
  whichkey = require "which-key"
  nvimtree = require "nvim-tree"

  nvimtree.setup {
    disable_netrw: true
    sync_root_with_cwd: true
    reload_on_bufenter: true
    sort_by: "case_sensitive"
    view:
      adaptive_size: true
    renderer:
      group_empty: true
    filters:
      dotfiles: false
  }

  vim.keymap.set "n", "<C-t>", ":NvimTreeToggle<cr>|<C-w>p",
    noremap: true

  whichkey.register {
    t:
      name: "Tree"
      t: { "<cmd>NvimTreeToggle<cr>", "Toggle" }
      f: { "<cmd>NvimTreeFindFile<cr>", "Find File" }
      c: { "<cmd>NvimTreeCollapseKeepBuffers<cr>", "Collapse & Keep Buffers" }
      C: { "<cmd>NvimTreeCollapse<cr>", "Collapse" }
  }, {
    prefix: "<leader>"
  }

folds = () ->
  whichkey = require "which-key"

  -- Folds
  vim.opt.foldenable = true

  -- Don"t ignore anything (e.g. comments) when making folds
  vim.opt.foldignore = ""

  whichkey.register {
    F:
      name: "Fold"
      c: { classFoldMode, "Class" }
      d: { defaultFoldMode, "Default" }
      f: { functionFoldMode, "Function" }
  }, {
    prefix: "<leader>"
  }

linenumbers = () ->
  vim.opt.number = true
  vim.opt.relativenumber = true

movement = () ->
  -- make movement keys wrap to the next/previous line
  vim.opt.whichwrap = "b,s,h,l,<,>,[,]"

  -- Fix backspace behaviour
  vim.opt.backspace = "indent,eol,start"

  -- keep a certain number of lines visible (center the cursor, document moves
  -- under it)
  vim.opt.scrolloff = 50

  -- Make the mouse usable everywhere.
  vim.opt.mouse = "a"

  -- Comments.
  nvimComment = require "nvim_comment"
  nvimComment.setup!

  -- Map <C-_> as well as <C-/> because apparently terminals are terrible.
  vim.keymap.set "n", "<C-_>", ":CommentToggle<cr>",
    noremap: true
  vim.keymap.set "n", "<C-/>", ":CommentToggle<cr>",
    noremap: true
  vim.keymap.set "v", "<C-_>", ":\"<,\">CommentToggle<cr>",
    noremap: true
  vim.keymap.set "v", "<C-/>", ":\"<,\">CommentToggle<cr>",
    noremap: true

quickfix = () ->
  whichkey = require "which-key"
  trouble = require "trouble"

  trouble.setup {
    auto_open: false
    auto_close: false
    auto_preview: true
    use_diagnostic_signs: true
  }

  whichkey.register {
    x:
      name: "Quickfix"
      x: { "<cmd>TroubleToggle<cr>", "Toggle" }
      w: { "<cmd>TroubleToggle workspace_diagnostics<cr>", "Workspace" }
      d: { "<cmd>TroubleToggle document_diagnostics<cr>", "Document" }
      l: { "<cmd>TroubleToggle loclist<cr>", "Loclist" }
      q: { "<cmd>TroubleToggle quickfix<cr>", "Quickfix" }
      R: { "<cmd>TroubleToggle lsp_references<cr>", "References" }
  }, {
    prefix: "<leader>"
  }

saveFile = () ->
  vim.keymap.set "n", "<C-s>", ":write<cr>", {}
  vim.keymap.set "i", "<C-s>", "<esc>:write<cr>a", {}

  indentBlankline = require "indent_blankline"
  indentBlankline.setup {
    show_current_context: true
    show_current_context_start: true
  }

bufferSearch = () ->
  -- Ignore case in searches.
  vim.opt.ignorecase = true
  -- Don"t ignore case with capitals.
  vim.opt.smartcase = true

  -- Highlight searches as you type.
  vim.opt.hlsearch = true
  -- Show matches while typing.
  vim.opt.incsearch = true

findModalDialog = () ->
  telescope = require "telescope"
  telescopeBuiltin = require "telescope.builtin"
  whichkey = require "which-key"

  telescope.setup {}

  findFiles = () ->
    telescopeBuiltin.find_files {
      hidden: true
    }

  vim.keymap.set "n", "<C-p>", findFiles,
    noremap: true

  whichkey.register {
    f:
      name: "Find"
      C: { telescopeBuiltin.command_history, "command history" }
      "/": { telescopeBuiltin.current_buffer_fuzzy_find, "in buffer" }
      b: { telescopeBuiltin.buffers, "buffers" }
      c: { telescopeBuiltin.commands, "commands" }
      g:
        name: "Git",
        b: { telescopeBuiltin.git_branches, "branches" }
        c: { telescopeBuiltin.git_commits, "commits" }
        d: { telescopeBuiltin.git_bcommits, "diff" }
        s: { telescopeBuiltin.git_status, "status" }
        t: { telescopeBuiltin.git_stash, "stash" }
      f: { telescopeBuiltin.live_grep, "in files" }
      h: { telescopeBuiltin.help_tags, "help tags" }
      p: { findFiles, "files" }
      q: { telescopeBuiltin.quickfix, "quickfix" }
      r: { telescopeBuiltin.registers, "registers" }
      l:
        name: "LSP"
        a: { telescopeBuiltin.lsp_code_actions, "code actions" }
        d: { telescopeBuiltin.lsp_definitions, "definitions" }
        t: { telescopeBuiltin.lsp_type_definitions, "type definitions" }
        i: { telescopeBuiltin.lsp_implementations, "implementations" }
        r: { telescopeBuiltin.lsp_references, "references" }
        s: { telescopeBuiltin.lsp_document_symbols, "document symbols" }
        w: { telescopeBuiltin.lsp_workspace_symbols, "workspace symbols" }
  }, {
    prefix: "<leader>"
  }

splits = () ->
  whichkey = require "which-key"

  -- Splitting a window horizontally (:split) will put the new window below the current one.
  vim.opt.splitbelow = true

  -- Splitting a window vertically (:vsplit) will put the new window to the right of the current one.
  vim.opt.splitright = true

  -- move through splits
  vim.keymap.set "n", "<C-h>", "<C-w>h",
    noremap: true
  vim.keymap.set "n", "<C-j>", "<C-w>j",
    noremap: true
  vim.keymap.set "n", "<C-k>", "<C-w>k",
    noremap: true
  vim.keymap.set "n", "<C-l>", "<C-w>l",
    noremap: true

  whichkey.register {
    w:
      name: "Window"
      c: { "<C-W>c", "Close" }
      h: { "<C-W>h", "Left" }
      H: { "<C-W>5>", "Left (Resize)" }
      j: { "<C-W>j", "Down" }
      J: { ":resize +5", "Down (Resize)" }
      k: { "<C-W>k", "Up" }
      K: { ":resize -5", "Up (Resize)" }
      l: { "<C-W>l", "Right" }
      L: { "<C-W>5<", "Right (Resize)" }
      "=": { "<C-W>=", "Balance" }
      s: { "<C-W>s", "Horizontal" }
      "-": { "<C-W>s", "Horizontal" }
      v: { "<C-W>v", "Vertical" }
      "|": { "<C-W>v", "Vertical" }
  }, {
    prefix: "<leader>"
  }

statusline = () ->
  lualine = require "lualine"

  lualine.setup {
    options:
      icons_enabled: true
      theme: "auto"
      component_separators:
        left: ""
        right: ""
      section_separators:
        left: ""
        right: ""
      disabled_filetypes:
        statusline: {}
        winbar: {}
      ignore_focus: {}
      always_divide_middle: true
      globalstatus: false
      refresh:
        statusline: 1000
        tabline: 1000
        winbar: 1000
    sections:
      lualine_a: { "mode" }
      lualine_b: { "branch", "diff", "diagnostics" }
      lualine_c: { "filename" }
      lualine_x: { "encoding", "fileformat", "filetype" }
      lualine_y: { "progress" }
      lualine_z: { "location" }
    inactive_sections:
      lualine_a: {}
      lualine_b: {}
      lualine_c: { "filename" }
      lualine_x: { "location" }
      lualine_y: {}
      lualine_z: {}
  }

visualInformation = () ->
  -- Display a column with signs when necessary.
  -- vim.opt.signcolumn = "auto"
  vim.opt.signcolumn = "auto"

  -- Highlight the line the cursor is on.
  vim.opt.cursorline = true

  -- Don"t highlight the column the cursor is on.
  vim.opt.cursorcolumn = false

initialize = () ->
  -- TODO: Find a place for which-key configuration.
  whichkey = require 'which-key'

  whichkey.setup {
  -- plugins = {
  --   marks = false,
  --   registers = false,
  --   spelling = { enabled = false, suggestions = 20 },
  --   presets = {
  --     operators = false,
  --     motions = false,
  --     text_objects = false,
  --     windows = false,
  --     nav = false,
  --     z = false,
  --     g = false,
  --   },
  --   window = { border = 'single', position = 'top', margin = { 1, 0, 1, 0 }, padding = { 2, 2, 2, 2 } },
  --   layout = { height = { min = 4, max = 25 }, width = { min = 20, max = 50 }, spacing = 3, align = 'center' },
  -- },
  }

  -- Disable NetRW
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  -- Set the map leader to space
  vim.g.mapleader = ' '

  backupFiles!
  swapFiles!
  undoFiles!
  buffers!
  colorscheme!
  completion!
  copypaste!
  filetabs!
  filetreesidebar!
  folds!
  linenumbers!
  movement!
  quickfix!
  saveFile!
  bufferSearch!
  findModalDialog!
  splits!
  statusline!
  visualInformation!

initialize!
