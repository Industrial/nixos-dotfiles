# Assay: neovim status line.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./status-line.nix];};
in
  assay.suite "status-line" {
    enablesLualine = assay.eq cfg.programs.nixvim.plugins.lualine.enable true;
  }
