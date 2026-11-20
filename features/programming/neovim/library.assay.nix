# Assay: neovim shared Lua libraries.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./library.nix];};
  plugins = cfg.programs.nixvim.plugins;
in
  assay.suite "library" {
    enablesMini = assay.eq plugins.mini.enable true;
    # autoLoad: put on the runtime path at startup rather than left as an opt plugin.
    autoLoadsMini = assay.eq plugins.mini.autoLoad true;
    # File-type icons for the tree, tab line and pickers.
    enablesWebDevicons = assay.eq plugins.web-devicons.enable true;
  }
