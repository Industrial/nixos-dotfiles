# Assay: neovim editing helpers.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./editing.nix];};
  plugins = cfg.programs.nixvim.plugins;
in
  assay.suite "editing" {
    # Closes brackets, braces and quotes as they are opened.
    autoClosesPairs = assay.eq plugins.autoclose.enable true;
    # Adds `end`/`endfunction` after a block opener.
    addsBlockEnds = assay.eq plugins.endwise.enable true;
  }
