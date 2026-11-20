# Assay: neovim test runner and coverage.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The which-key menu is Lua, so the generated extraConfigLua is the
# artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  system = nixos.evalSystem {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./testing.nix];};
  cfg = system.config;
  nv = cfg.programs.nixvim;
  inherit (nv.plugins) neotest coverage;
  keys =
    map (k: {
      inherit (k) mode key action;
      inherit (k.options) desc;
    })
    nv.keymaps;
  run = key: lua: desc: {
    inherit key desc;
    mode = "n";
    action = "<cmd>lua require('neotest').${lua}<cr>";
  };
  enabledAdapters = builtins.attrNames (lib.filterAttrs (_: a: a.enable) neotest.adapters);
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" nv.extraConfigLua)) ks;
  added = builtins.filter (n: !(nixos.hasPackage nixos.baseline n)) (nixos.packageNames cfg);
in
  assay.suite "testing" {
    enablesNeotest = assay.eq neotest.enable true;
    rustAndPythonAdaptersOnly = assay.eq enabledAdapters ["python" "rust"];
    pythonRunsPytest = assay.eq neotest.adapters.python.settings.runner "pytest";
    # Pinned to the system python3, not whatever python is first on PATH in a project.
    pythonInterpreterPinned =
      assay.eq neotest.adapters.python.settings.python "${system.pkgs.python3}/bin/python3";

    # Results go to the quickfix list without stealing focus.
    quickfixFilledNotOpened = assay.eq neotest.settings.quickfix {
      enabled = true;
      open = false;
    };
    statusAsVirtualTextAndSigns = assay.eq neotest.settings.status {
      enabled = true;
      virtual_text = true;
      signs = true;
    };

    enablesCoverage = assay.eq coverage.enable true;
    coverageAutoReloads = assay.eq coverage.settings.auto_reload true;
    coverageColours = assay.eq coverage.settings.highlights {
      covered.fg = "#C3E88D";
      uncovered.fg = "#F07178";
    };

    leaderTRunsTests = assay.eq keys [
      (run "<leader>tr" "run.run()" "Run Nearest Test")
      (run "<leader>tf" "run.run(vim.fn.expand('%'))" "Run File Tests")
      (run "<leader>td" "run.run({strategy = 'dap'})" "Debug Nearest Test")
      (run "<leader>ts" "summary.toggle()" "Test Summary")
      (run "<leader>to" "output.open({enter = true})" "Test Output")
      (run "<leader>tp" "output_panel.toggle()" "Test Output Panel")
    ];

    registersTestMenu = assay.eq (unregistered [
      "<leader>t"
      "<leader>ta"
      "<leader>td"
      "<leader>tf"
      "<leader>tl"
      "<leader>to"
      "<leader>tp"
      "<leader>tr"
      "<leader>ts"
      "<leader>tS"
      "<leader>tw"
    ]) [];

    installsPytestTooling = assay.eq added ["pytest" "pytest-cov"];
  }
