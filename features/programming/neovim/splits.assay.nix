# Assay: neovim window splits.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./splits.nix];};
  nv = cfg.programs.nixvim;
  keys = map (k: {inherit (k) mode key action;}) nv.keymaps;
  move = dir: {
    mode = "n";
    key = "<C-${dir}>";
    action = "<C-w>${dir}";
  };
in
  assay.suite "splits" {
    enablesSmartSplits = assay.eq nv.plugins.smart-splits.enable true;
    horizontalSplitGoesBelow = assay.eq nv.opts.splitbelow true;
    verticalSplitGoesRight = assay.eq nv.opts.splitright true;

    # Ctrl-h/j/k/l move between windows, and those are the only mappings added here.
    ctrlHjklMovesBetweenWindows = assay.eq keys (map move ["h" "j" "k" "l"]);
  }
