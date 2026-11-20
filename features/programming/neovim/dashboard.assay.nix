# Assay: neovim start screen.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./dashboard.nix];};
in
  assay.suite "dashboard" {
    enablesDashboard = assay.eq cfg.programs.nixvim.plugins.dashboard.enable true;
  }
