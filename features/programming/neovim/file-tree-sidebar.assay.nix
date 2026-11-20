# Assay: neovim file tree.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
# The which-key menu is Lua, so it is matched as text: the generated extraConfigLua is
# the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./file-tree-sidebar.nix];};
  nv = cfg.programs.nixvim;
  has = s: lib.hasInfix s nv.extraConfigLua;
in
  assay.suite "file-tree-sidebar" {
    # Netrw is disabled in default.nix, so neo-tree is the only file browser.
    enablesNeoTree = assay.eq nv.plugins.neo-tree.enable true;

    menuGroupNamedTree = assay.eq (has ''{ "<leader>t", group = "Tree" }'') true;
    leaderTfRevealsCurrentFile = assay.eq (has ''{ "<leader>tf", "<cmd>Neotree reveal<cr>"'') true;
    leaderTtTogglesTree = assay.eq (has ''{ "<leader>tt", "<cmd>Neotree toggle<cr>"'') true;
  }
