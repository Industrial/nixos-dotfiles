# Assay: neovim in-buffer search behaviour.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./buffer-search.nix];};
  opts = cfg.programs.nixvim.opts;
in
  assay.suite "buffer-search" {
    ignoresCase = assay.eq opts.ignorecase true;
    # ...unless the pattern contains a capital.
    respectsCapitals = assay.eq opts.smartcase true;
    highlightsMatches = assay.eq opts.hlsearch true;
    searchesAsYouType = assay.eq opts.incsearch true;
  }
