# Assay: neovim system clipboard mappings.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./copy-paste.nix];};
  keys = map (k: {inherit (k) mode key action;}) cfg.programs.nixvim.keymaps;
  inMode = mode: builtins.filter (k: k.mode == mode) keys;
  map' = mode: key: action: {inherit mode key action;};
in
  assay.suite "copy-paste" {
    # <leader>d/y/p use the "+ (clipboard) register, <leader>D/Y/P the "* (selection) one.
    normalModeUsesBothRegisters = assay.eq (inMode "n") [
      (map' "n" "<leader>d" "\"+d")
      (map' "n" "<leader>y" "\"+y")
      (map' "n" "<leader>p" "\"+p")
      (map' "n" "<leader>D" "\"*d")
      (map' "n" "<leader>Y" "\"*y")
      (map' "n" "<leader>P" "\"*p")
    ];

    visualModeUsesClipboard = assay.eq (inMode "v") [
      (map' "v" "<leader>d" "\"+d")
      (map' "v" "<leader>y" "\"+y")
      (map' "v" "<leader>p" "\"+p")
    ];

    # Ctrl-V in insert mode pastes the clipboard and returns to insert mode.
    insertModeCtrlVPastes = assay.eq (inMode "i") [(map' "i" "<C-v>" "<esc>\"+pi")];

    # Nothing beyond the three groups above (no operator-pending or select-mode maps).
    onlyNormalVisualInsert = assay.eq (builtins.length keys) 10;
  }
