# Assay: neovim commenting.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./commenting.nix];};
  nv = cfg.programs.nixvim;
  keys = map (k: {inherit (k) mode key action;}) nv.keymaps;
  toggle = mode: key: kind: {
    inherit mode key;
    action = "<Plug>(comment_toggle_${kind})";
  };
in
  assay.suite "commenting" {
    enablesComment = assay.eq nv.plugins.comment.enable true;

    # Ctrl-/ toggles line comments, Ctrl-Shift-/ block comments, in normal and visual mode.
    ctrlSlashToggles = assay.eq keys [
      (toggle "n" "<C-/>" "linewise_current")
      (toggle "n" "<C-S-/>" "blockwise_current")
      (toggle "v" "<C-/>" "linewise_visual")
      (toggle "v" "<C-S-/>" "blockwise_visual")
    ];

    setsUpComment = assay.eq (lib.hasInfix "require('Comment')" nv.extraConfigLua) true;
  }
