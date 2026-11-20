# Assay: neovim indentation detection.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./indentation.nix];};
in
  assay.suite "indentation" {
    # Detects each file's indentation instead of imposing one.
    enablesIndentOMatic = assay.eq cfg.programs.nixvim.plugins.indent-o-matic.enable true;
  }
