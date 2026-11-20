# Assay: neovim refactoring.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The which-key menu is Lua, so the generated extraConfigLua is the
# artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./refactoring.nix];};
  nv = cfg.programs.nixvim;
  keys =
    map (k: {
      inherit (k) mode key action;
      inherit (k.options) desc silent;
    })
    nv.keymaps;
  refactor = mode: key: name: desc: {
    inherit mode key desc;
    action = "<cmd>lua require('refactoring').refactor('${name}')<cr>";
    silent = true;
  };
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "\"${k}\"" nv.extraConfigLua)) ks;
in
  assay.suite "refactoring" {
    enablesRefactoring = assay.eq nv.plugins.refactoring.enable true;
    # Needed for the <leader>rr picker below.
    loadsTelescopeExtension = assay.eq nv.plugins.refactoring.enableTelescope true;

    extractionsInVisualMode = assay.eq (builtins.filter (k: k.mode == "x") keys) [
      (refactor "x" "<leader>re" "Extract Function" "Extract Function")
      (refactor "x" "<leader>rf" "Extract Function To File" "Extract to File")
      (refactor "x" "<leader>rv" "Extract Variable" "Extract Variable")
      (refactor "x" "<leader>ri" "Inline Variable" "Inline Variable")
    ];

    blockAndInlineInNormalMode = assay.eq (builtins.filter (k: k.mode == "n") keys) [
      (refactor "n" "<leader>rb" "Extract Block" "Extract Block")
      (refactor "n" "<leader>rI" "Inline Function" "Inline Function")
    ];

    registersRefactorMenu =
      assay.eq (unregistered ["<leader>r" "<leader>re" "<leader>rf" "<leader>rv" "<leader>ri" "<leader>rb" "<leader>rI" "<leader>rr"]) [];

    leaderRrOpensTelescopePicker =
      assay.eq (lib.hasInfix "require('telescope').extensions.refactoring.refactors()" nv.extraConfigLua) true;
  }
