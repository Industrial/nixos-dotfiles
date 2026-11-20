# Assay: neovim persistent undo.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  eval = settings:
    (nixos.eval {
      modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./undo-files.nix];
      inherit settings;
    }).programs.nixvim.opts;
in
  assay.suite "undo-files" {
    persistsUndoHistory = assay.eq (eval {}).undofile true;

    # Kept out of the working tree, under the user's home from settings.userdir.
    undoDirFollowsUserdir =
      assay.eq (eval {userdir = "/home/probe";}).undodir "/home/probe/.config/nvim/undo";
  }
