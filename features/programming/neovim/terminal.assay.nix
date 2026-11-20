# Assay: neovim terminal.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./terminal.nix];};
  toggleterm = cfg.programs.nixvim.plugins.toggleterm;
in
  assay.suite "terminal" {
    enablesToggleterm = assay.eq toggleterm.enable true;
    # Passed through as raw Lua, so toggleterm sees the long string [[<c-t>]] = "<c-t>".
    ctrlTToggles = assay.eq toggleterm.settings.open_mapping {__raw = "[[<c-t>]]";};
    opensFloating = assay.eq toggleterm.settings.direction "float";
    curvedBorder = assay.eq toggleterm.settings.float_opts.border "curved";
  }
