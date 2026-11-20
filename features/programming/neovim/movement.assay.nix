# Assay: neovim cursor movement.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./movement.nix];};
  nv = cfg.programs.nixvim;
in
  assay.suite "movement" {
    # Horizontal movement keys wrap onto the previous/next line.
    movementWrapsLines = assay.eq nv.opts.whichwrap "b,s,h,l,<,>,[,]";
    backspaceCrossesEverything = assay.eq nv.opts.backspace "indent,eol,start";
    # Large scrolloff keeps the cursor centred and moves the document under it.
    keepsCursorCentred = assay.eq nv.opts.scrolloff 50;
    mouseEverywhere = assay.eq nv.opts.mouse "a";

    # Provides :Bdelete/:Bwipeout, which buffers.nix maps <C-Q> and <leader>b* to.
    enablesBbye = assay.eq nv.plugins.vim-bbye.enable true;
  }
