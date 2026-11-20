# Assay: neovim command-line completion menu.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The wilder setup is Lua, so the generated extraConfigLua is the
# artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./wildmenu.nix];};
  nv = cfg.programs.nixvim;
  # Whitespace-insensitive, so reformatting the Lua does not fail a claim.
  squash = s: lib.concatStrings (lib.filter builtins.isString (builtins.split "[[:space:]]+" s));
  lua = squash nv.extraConfigLua;
  has = s: lib.hasInfix (squash s) lua;
in
  assay.suite "wildmenu" {
    enablesWilder = assay.eq nv.plugins.wilder.enable true;

    # Completion for commands and both search directions.
    coversCommandAndSearch = assay.eq (has "modes = { ':', '/', '?' }") true;
    rendersBorderedPopup = assay.eq (has "wilder.popupmenu_border_theme(") true;
    roundedBorder = assay.eq (has "border = 'rounded'") true;
    showsDevicons = assay.eq (has "wilder.popupmenu_devicons()") true;
  }
