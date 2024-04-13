{...}: {
  programs.nixvim.extraConfigLua = ''
    telescopeBuiltin = require("telescope.builtin")
    findFiles = function()
      telescopeBuiltin.find_files({
        find_command = { "rg", "--no-ignore", "--files" },
        hidden = true,
      })
    end
    vim.keymap.set("n", "<C-p>", findFiles, {
      noremap = true,
      silent = true,
    })
    require("which-key").register({
      f = {
        name = "Find",
        ["/"] = { telescopeBuiltin.current_buffer_fuzzy_find, "in buffer" },
        C = { telescopeBuiltin.command_history, "command history" },
        b = { telescopeBuiltin.buffers, "buffers" },
        c = { telescopeBuiltin.commands, "commands" },
        g = {
          name = "Git",
          b = { telescopeBuiltin.git_branches, "branches" },
          c = { telescopeBuiltin.git_commits, "commits" },
          d = { telescopeBuiltin.git_bcommits, "diff" },
          s = { telescopeBuiltin.git_status, "status" },
          t = { telescopeBuiltin.git_stash, "stash" },
        },
        f = { telescopeBuiltin.live_grep, "in files" },
        h = { telescopeBuiltin.help_tags, "help tags" },
        p = { findFiles, "files" },
        q = { telescopeBuiltin.quickfix, "quickfix" },
        r = { telescopeBuiltin.registers, "registers" },
        l = {
          name = "LSP",
          a = { telescopeBuiltin.lsp_code_actions, "code actions" },
          d = { telescopeBuiltin.lsp_definitions, "definitions" },
          t = { telescopeBuiltin.lsp_type_definitions, "type definitions" },
          i = { telescopeBuiltin.lsp_implementations, "implementations" },
          r = { telescopeBuiltin.lsp_references, "references" },
          s = { telescopeBuiltin.lsp_document_symbols, "document symbols" },
          w = { telescopeBuiltin.lsp_workspace_symbols, "workspace symbols" },
        },
      },
    }, {
      prefix = "<leader>"
    })
  '';
}

        # "/" = { telescopeBuiltin.current_buffer_fuzzy_find, "in buffer" },
