# Assay: neovim keybinding menu (which-key).
#
# Most feature modules register their menus through require("which-key") in Lua, so this
# plugin being enabled is load-bearing for the whole editor (default.assay.nix checks the
# composed config). Claims read the evaluated nixvim config.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./keybind-menu.nix];};
  nv = cfg.programs.nixvim;
  wk = nv.plugins.which-key.settings;
in
  assay.suite "keybind-menu" {
    enablesWhichKey = assay.eq nv.plugins.which-key.enable true;

    # Pops up immediately for every prefix instead of after a delay.
    popsUpImmediately = assay.eq nv.opts.timeoutlen 0;

    showsRegisters = assay.eq wk.plugins.registers true;
    showsSpellingSuggestions = assay.eq wk.plugins.spelling.enabled true;
    enablesAllPresets = assay.eq wk.plugins.presets {
      operators = true;
      motions = true;
      textObjects = true;
      windows = true;
      nav = true;
      z = true;
      g = true;
    };

    centredLayout = assay.eq wk.layout {
      width = {
        min = 20;
        max = 50;
      };
      height = {
        min = 4;
        max = 25;
      };
      spacing = 3;
      align = "center";
    };
  }
