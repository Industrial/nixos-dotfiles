# Assay: neovim git integration (gitsigns, neogit, diffview).
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. on_attach and the which-key menu are Lua, so those generated
# strings are the artifact and are matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./git.nix];};
  nv = cfg.programs.nixvim;
  inherit (nv.plugins) gitsigns neogit diffview;
  onAttach = gitsigns.settings.on_attach.__raw;
  keys =
    map (k: {
      inherit (k) mode key action;
      inherit (k.options) desc;
    })
    nv.keymaps;
  hunk = key: cmd: desc: {
    inherit key desc;
    mode = "n";
    action = "<cmd>Gitsigns ${cmd}<cr>";
  };
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" nv.extraConfigLua)) ks;
  added = builtins.filter (n: !(nixos.hasPackage nixos.baseline n)) (nixos.packageNames cfg);
in
  assay.suite "git" {
    enablesGitsigns = assay.eq gitsigns.enable true;
    gutterSigns = assay.eq gitsigns.settings.signs {
      add.text = "│";
      change.text = "│";
      delete.text = "_";
      topdelete.text = "‾";
      changedelete.text = "~";
      untracked.text = "┆";
    };
    noInlineBlame = assay.eq gitsigns.settings.current_line_blame false;
    # ]c / [c jump between hunks (falling back to the built-in motion in diff mode).
    bracketCNavigatesHunks =
      assay.eq (lib.hasInfix "map('n', ']c'" onAttach && lib.hasInfix "map('n', '[c'" onAttach) true;

    enablesNeogit = assay.eq neogit.enable true;
    neogitIntegrations = assay.eq neogit.settings.integrations {
      telescope = true;
      diffview = true;
    };
    neogitOpensInSplits = assay.eq [neogit.settings.kind neogit.settings.commit_popup.kind neogit.settings.popup.kind] ["split" "split" "split"];

    enablesDiffview = assay.eq diffview.enable true;
    diffviewEnhancedHighlight = assay.eq diffview.settings.enhanced_diff_hl true;
    diffviewLayouts = assay.eq diffview.settings.view {
      default.layout = "diff2_horizontal";
      merge_tool.layout = "diff3_horizontal";
    };

    leaderHActsOnHunks = assay.eq keys [
      (hunk "<leader>hs" "stage_hunk" "Stage Hunk")
      (hunk "<leader>hr" "reset_hunk" "Reset Hunk")
      (hunk "<leader>hu" "undo_stage_hunk" "Undo Stage Hunk")
      (hunk "<leader>hp" "preview_hunk" "Preview Hunk")
      (hunk "<leader>hb" "blame_line" "Blame Line")
    ];

    registersGitMenu = assay.eq (unregistered [
      "<leader>g"
      "<leader>gg"
      "<leader>gc"
      "<leader>gp"
      "<leader>gP"
      "<leader>gl"
      "<leader>gd"
      "<leader>gD"
      "<leader>gh"
      "<leader>gH"
      "<leader>gm"
    ]) [];
    registersHunkMenu = assay.eq (unregistered [
      "<leader>h"
      "<leader>hs"
      "<leader>hr"
      "<leader>hS"
      "<leader>hu"
      "<leader>hR"
      "<leader>hp"
      "<leader>hb"
      "<leader>hd"
    ]) [];

    # The plugins shell out to git, so it is installed alongside them, and nothing else is.
    installsOnlyGit = assay.eq added ["git"];
  }
