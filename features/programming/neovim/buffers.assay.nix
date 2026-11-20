# Assay: neovim buffer handling.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
# The which-key menu is Lua, so it is matched as text: the generated extraConfigLua is
# the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./buffers.nix];};
  nv = cfg.programs.nixvim;
  keys = map (k: {inherit (k) mode key action;}) nv.keymaps;
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" nv.extraConfigLua)) ks;
in
  assay.suite "buffers" {
    # Switching away from a modified buffer keeps it loaded instead of refusing.
    keepsHiddenBuffers = assay.eq nv.opts.hidden true;
    doesNotWrapLines = assay.eq nv.opts.wrap false;

    tabCyclesBuffers = assay.eq keys [
      {
        mode = "n";
        key = "<Tab>";
        action = "<cmd>bn<cr>";
      }
      {
        mode = "n";
        key = "<S-Tab>";
        action = "<cmd>bp<cr>";
      }
      {
        mode = "n";
        key = "<C-Q>";
        action = "<cmd>Bwipeout<cr>";
      }
    ];

    registersBufferMenu =
      assay.eq (unregistered ["<leader>b" "<leader>bb" "<leader>bd" "<leader>bn" "<leader>bp" "<leader>bw"]) [];
    menuGroupNamedBuffers = assay.eq (lib.hasInfix ''{ "<leader>b", group = "Buffers" }'' nv.extraConfigLua) true;
  }
