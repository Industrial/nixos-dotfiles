# Assay: neovim debugging (nvim-dap).
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. The UI listeners and which-key menu are Lua, so the generated
# extraConfigLua is the artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  system = nixos.evalSystem {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./debug-adapter-protocol.nix];};
  cfg = system.config;
  nv = cfg.programs.nixvim;
  inherit (nv.plugins) dap;
  lua = nv.extraConfigLua;
  keys =
    map (k: {
      inherit (k) mode key action;
      inherit (k.options) desc;
    })
    nv.keymaps;
  step = key: fn: desc: {
    inherit key;
    mode = "n";
    action = "<cmd>lua require('dap').${fn}()<cr>";
    desc = "Debug: ${desc}";
  };
  # Which of `ks` the Lua never registers with which-key; [] when all are there.
  unregistered = ks: builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" lua)) ks;
  added = builtins.filter (n: !(nixos.hasPackage nixos.baseline n)) (nixos.packageNames cfg);
in
  assay.suite "debug-adapter-protocol" {
    enablesDap = assay.eq dap.enable true;
    enablesDapUi = assay.eq nv.plugins.dap-ui.enable true;
    enablesVirtualText = assay.eq nv.plugins.dap-virtual-text.enable true;
    enablesDapPython = assay.eq nv.plugins.dap-python.enable true;

    # The lldb adapter is a binary from the same lldb the module installs.
    lldbAdapterFromLldbPackage =
      assay.eq (lib.hasPrefix "${system.pkgs.lldb}/bin/" dap.adapters.executables.lldb.command) true;

    rustLaunchConfigurations = assay.eq (map (c: {inherit (c) name type request;}) dap.configurations.rust) [
      {
        name = "Launch";
        type = "lldb";
        request = "launch";
      }
      {
        name = "Launch (with args)";
        type = "lldb";
        request = "launch";
      }
    ];

    # Scopes/breakpoints/stacks/watches on the left, REPL and console at the bottom.
    dapUiLayout = assay.eq (map (l: {
        inherit (l) position size;
        elements = map (e: e.id) l.elements;
      })
      nv.plugins.dap-ui.settings.layouts) [
      {
        position = "left";
        size = 40;
        elements = ["scopes" "breakpoints" "stacks" "watches"];
      }
      {
        position = "bottom";
        size = 10;
        elements = ["repl" "console"];
      }
    ];
    dapUiFloatsCloseOnEscOrQ = assay.eq nv.plugins.dap-ui.settings.floating.mappings.close ["<Esc>" "q"];

    functionKeysStep = assay.eq keys [
      (step "<F5>" "continue" "Start/Continue")
      (step "<F10>" "step_over" "Step Over")
      (step "<F11>" "step_into" "Step Into")
      (step "<F12>" "step_out" "Step Out")
    ];

    # The UI opens when a session initialises and closes when it terminates or exits.
    uiFollowsSession = assay.eq (map (s: lib.hasInfix s lua) [
      "dap.listeners.after.event_initialized['dapui_config'] = function()\n  dapui.open()"
      "dap.listeners.before.event_terminated['dapui_config'] = function()\n  dapui.close()"
      "dap.listeners.before.event_exited['dapui_config'] = function()\n  dapui.close()"
    ]) [true true true];

    registersDebugMenu = assay.eq (unregistered [
      "<leader>d"
      "<leader>db"
      "<leader>dB"
      "<leader>dc"
      "<leader>dC"
      "<leader>dd"
      "<leader>dg"
      "<leader>di"
      "<leader>do"
      "<leader>dO"
      "<leader>dp"
      "<leader>dr"
      "<leader>ds"
      "<leader>dt"
      "<leader>du"
    ]) [];

    installsLldbAndDebugpy = assay.eq added ["lldb" "debugpy"];
  }
