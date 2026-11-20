# Assay: neovim startup layout.
#
# The module is Lua only, so the generated extraConfigLua (read from the evaluated
# nixvim config, not from the module source) is the artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./initialize.nix];};
  lua = cfg.programs.nixvim.extraConfigLua;
in
  assay.suite "initialize" {
    runsOnVimEnter = assay.eq (lib.hasInfix ''nvim_create_autocmd("VimEnter"'' lua) true;
    # Opens the file tree on the left (neo-tree, file-tree-sidebar.nix)...
    revealsTreeOnLeft = assay.eq (lib.hasInfix ''vim.cmd("Neotree filesystem reveal left")'' lua) true;
    # ...then hands focus back to the editor window on its right.
    focusesEditorAfter = assay.eq (lib.hasInfix ''vim.cmd("wincmd l")'' lua) true;
  }
