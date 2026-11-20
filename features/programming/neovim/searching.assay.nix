# Assay: neovim searching (telescope, flash).
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The mappings are Lua (they call telescope/flash functions), so the
# generated extraConfigLua is the artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./searching.nix];};
  nv = cfg.programs.nixvim;
  lua = nv.extraConfigLua;
  has = s: lib.hasInfix s lua;
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(has "{ \"${k}\"")) ks;
in
  assay.suite "searching" {
    enablesTelescope = assay.eq nv.plugins.telescope.enable true;
    enablesFlash = assay.eq nv.plugins.flash.enable true;

    # Ctrl-P finds files with ripgrep, including ignored and hidden ones.
    ctrlPFindsFiles = assay.eq (has ''vim.keymap.set("n", "<C-p>", findFiles'') true;
    findFilesIgnoresGitignore = assay.eq (has ''find_command = { "rg", "--no-ignore", "--files" }'') true;
    findFilesIncludesHidden = assay.eq (has "hidden = true") true;

    # s / S jump with flash in normal and visual mode.
    sJumpsWithFlash = assay.eq (has "vim.keymap.set({'n', 'x'}, 's',     flash.jump") true;
    capitalSJumpsByTreesitter = assay.eq (has "vim.keymap.set({'n', 'x'}, 'S',     flash.treesitter") true;

    registersFindMenu = assay.eq (unregistered [
      "<leader>f"
      "<leader>f/"
      "<leader>fC"
      "<leader>fb"
      "<leader>fc"
      "<leader>ff"
      "<leader>fg"
      "<leader>fgb"
      "<leader>fgc"
      "<leader>fgd"
      "<leader>fgs"
      "<leader>fgt"
      "<leader>fh"
      "<leader>fl"
      "<leader>fld"
      "<leader>fli"
      "<leader>flr"
      "<leader>fls"
      "<leader>flt"
      "<leader>flw"
      "<leader>fp"
      "<leader>fq"
      "<leader>fr"
    ]) [];

    registersSearchMenu = assay.eq (unregistered ["<leader>s" "<leader>sS" "<leader>ss"]) [];

    # Searching adds no mappings through the keymaps option; everything above is Lua.
    noDeclarativeKeymaps = assay.eq nv.keymaps [];
  }
