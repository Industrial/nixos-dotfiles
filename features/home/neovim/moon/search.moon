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

(() ->
  bufferSearch!
  findModalDialog!
)!
