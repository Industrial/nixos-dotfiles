# Assay: neovim on-screen information (gutter, context, diagnostics, messages).
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The which-key menu is Lua, so the generated extraConfigLua is the
# artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./visual-information.nix];};
  nv = cfg.programs.nixvim;
  keys =
    map (k: {
      inherit (k) mode key action;
      inherit (k.options) desc;
    })
    nv.keymaps;
  trouble = key: cmd: desc: {
    inherit key desc;
    mode = "n";
    action = "<cmd>Trouble ${cmd}<cr>";
  };
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" nv.extraConfigLua)) ks;
in
  assay.suite "visual-information" {
    showsLineNumbers = assay.eq nv.opts.number true;
    highlightsCursorLine = assay.eq nv.opts.cursorline true;
    # Sign column appears only when there are signs, growing up to 9 wide.
    signColumnOnDemand = assay.eq nv.opts.signcolumn "auto:1-9";

    enablesBarbecueContext = assay.eq nv.plugins.barbecue.enable true;
    enablesIndentGuides = assay.eq nv.plugins.indent-blankline.enable true;
    enablesIlluminate = assay.eq nv.plugins.illuminate.enable true;

    enablesTrouble = assay.eq nv.plugins.trouble.enable true;
    troublePanelAtBottom = assay.subset nv.plugins.trouble.settings {
      position = "bottom";
      height = 10;
      mode = "workspace_diagnostics";
    };

    enablesNoice = assay.eq nv.plugins.noice.enable true;
    # Markdown in LSP hovers/docs is rendered by noice instead of the built-in handlers.
    noiceOverridesLspMarkdown = assay.eq nv.plugins.noice.settings.lsp.override {
      "vim.lsp.util.convert_input_to_markdown_lines" = true;
      "vim.lsp.util.stylize_markdown" = true;
      "cmp.entry.get_documentation" = true;
    };
    noicePresets = assay.eq nv.plugins.noice.settings.presets {
      bottom_search = true;
      command_palette = true;
      long_message_to_split = true;
      inc_rename = false;
      lsp_doc_border = true;
    };

    leaderXOpensTrouble = assay.eq keys [
      (trouble "<leader>xx" "diagnostics toggle" "Diagnostics (Trouble)")
      (trouble "<leader>xX" "diagnostics toggle filter.buf=0" "Buffer Diagnostics")
      (trouble "<leader>xL" "loclist toggle" "Location List")
      (trouble "<leader>xQ" "qflist toggle" "Quickfix List")
    ];

    registersDiagnosticsMenu =
      assay.eq (unregistered ["<leader>x" "<leader>xx" "<leader>xX" "<leader>xL" "<leader>xQ"]) [];
  }
