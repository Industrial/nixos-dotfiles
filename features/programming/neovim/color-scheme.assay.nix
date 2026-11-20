# Assay: neovim colour scheme.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  eval = extra:
    (nixos.eval {
      modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./color-scheme.nix] ++ extra;
    }).programs.nixvim;
  nv = eval [];
in
  assay.suite "color-scheme" {
    enablesBase16 = assay.eq nv.colorschemes.base16.enable true;
    defaultsToAtelierEstuary = assay.eq nv.colorschemes.base16.colorscheme "atelier-estuary";

    # The scheme is only a default: a host or theme module can pick another without
    # mkForce (a plain definition would be a conflict if this were not mkDefault).
    schemeIsOverridable =
      assay.eq
      (eval [{programs.nixvim.colorschemes.base16.colorscheme = "gruvbox-dark-hard";}]).colorschemes.base16.colorscheme
      "gruvbox-dark-hard";

    # base16 needs 24-bit colour to render the palette faithfully.
    usesTrueColour = assay.eq nv.opts.termguicolors true;
  }
