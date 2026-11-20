# Assay: neovim direnv integration.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./environment.nix];};
in
  assay.suite "environment" {
    # Loads the project's direnv environment, so external programs called from vim see
    # the devenv/nix-shell toolchain.
    enablesDirenv = assay.eq cfg.programs.nixvim.plugins.direnv.enable true;
  }
