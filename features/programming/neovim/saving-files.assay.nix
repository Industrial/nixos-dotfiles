# Assay: neovim save shortcut.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./saving-files.nix];};
  keys = map (k: {inherit (k) mode key action;}) cfg.programs.nixvim.keymaps;
in
  assay.suite "saving-files" {
    # Ctrl-S writes the buffer in normal mode, and is the only mapping this module adds.
    ctrlSWrites = assay.eq keys [
      {
        mode = "n";
        key = "<C-s>";
        action = "<cmd>write<cr>";
      }
    ];
  }
