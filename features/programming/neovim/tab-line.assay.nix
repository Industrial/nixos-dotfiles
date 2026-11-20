# Assay: neovim tab line.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./tab-line.nix];};
in
  assay.suite "tab-line" {
    enablesBufferline = assay.eq cfg.programs.nixvim.plugins.bufferline.enable true;
  }
