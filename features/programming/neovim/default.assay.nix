# Assay: the composed neovim feature (features/programming/neovim/default.nix).
#
# The per-module suites evaluate each submodule alone; this one evaluates default.nix the
# way a host imports it (nixvim module included via inputs) and pins what only the
# composition can show: the whole config evaluates cleanly, and the plugins the
# submodules' Lua require() are actually enabled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  nv = cfg.programs.nixvim;
  failed = as: map (a: a.message) (builtins.filter (a: !a.assertion) as);
  keyIds = lib.concatMap (k: map (m: "${m} ${k.key}") (lib.toList k.mode)) nv.keymaps;
in
  assay.suite "neovim" {
    enablesNixvim = assay.eq nv.enable true;
    leaderIsSpace = assay.eq nv.globals.mapleader " ";
    # neo-tree replaces netrw; both netrw guards must be set for it to stay unloaded.
    disablesNetrw = assay.eq [nv.globals.loaded_netrw nv.globals.loaded_netrwPlugin] [1 1];
    installsClipboardProviders = assay.eq (map (nixos.hasPackage cfg) ["xsel" "xclip"]) [true true];

    # nixvim builds against the fleet's nixpkgs, not its own pin...
    nixvimUsesFlakeNixpkgs = assay.eq (toString nv.nixpkgs.source) (toString nixos.flakeInputs.nixpkgs);
    # ...which is also what silences its `follows` warning.
    noNixvimWarnings = assay.eq nv.warnings [];
    noSystemWarnings = assay.eq cfg.warnings [];
    noFailedAssertions = assay.eq (failed (cfg.assertions ++ nv.assertions)) [];

    # Options from the option-only submodules all reach the composed config.
    composesSubmoduleOptions = assay.subset nv.opts {
      backup = true;
      swapfile = true;
      undofile = true;
      ignorecase = true;
      hidden = true;
      splitbelow = true;
      number = true;
      termguicolors = true;
      timeoutlen = 0;
      scrolloff = 50;
    };

    # Submodule Lua require()s these plugins, which other submodules enable: which-key
    # (every menu), neo-tree (initialize.nix startup), telescope (buffers/searching/
    # refactoring), vim-bbye (:Bwipeout in buffers.nix), dap-ui (debug listeners).
    # Lists any that are not enabled; [] when all are.
    requiredPluginsEnabled = assay.eq (builtins.filter (n: !nv.plugins.${n}.enable) [
      "which-key"
      "neo-tree"
      "telescope"
      "vim-bbye"
      "dap"
      "dap-ui"
      "neotest"
      "neogit"
      "flash"
      "refactoring"
      "comment"
    ]) [];

    # No two submodules claim the same key in the same mode via the keymaps option.
    noDuplicateKeymaps = assay.eq (lib.unique (builtins.filter (i: lib.count (j: j == i) keyIds > 1) keyIds)) [];
  }
