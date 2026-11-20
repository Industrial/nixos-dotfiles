# Colocated suite for nix/devenv-modules/devenv.nix.
#
# devenv.nix is the import list for the vendored modules: a feature that drops out of it is
# silently unavailable (its `local.features.<x>.enable` becomes an unknown option in the root
# devenv.nix), and losing with-devenv or no-hooks-on-shell-entry brings back hook recursion on
# shell entry. Every claim evaluates the import list with feature-eval's stubs; the no-hooks
# claim also loads devenv's real tasks.nix so the mkForce is merged the way devenv merges it.
let
  assay = import ./lib/assay.nix;
  h = import ./lib/feature-eval.nix {};
  inherit (h) lib pkgs;

  features = [
    "dotenv"
    "git-hooks-prek"
    "languages-javascript"
    "languages-rust"
    "packages-base"
    "packages-formatters"
    "packages-rust-dev"
    "program-assay"
    "program-blaze"
    "program-moon"
  ];
  cfg = (h.evalModule ./devenv.nix {}).config;
  moonOn = h.feature ./devenv.nix {local.features.program-moon.enable = true;};

  lock = builtins.fromJSON (builtins.readFile ../../devenv.lock);
  devenvSrc = builtins.fetchTree (removeAttrs lock.nodes.devenv.locked ["dir"]);
  # Declared stand-ins for the devenv options tasks.nix writes to (see
  # no-hooks-on-shell-entry.assay.nix for why they cannot be freeform).
  taskStubs = {lib, ...}: let
    loose = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = {};
    };
  in {
    options = {
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [];
      };
      enterTest = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      infoSections = loose;
      devenv = loose;
      process = loose;
    };
  };
  # devenv's own definition (src/modules/integrations/git-hooks.nix), restated.
  upstream = {
    tasks."devenv:git-hooks:run" = {
      exec = "prek run -a";
      before = ["devenv:enterTest"];
    };
  };
  hookRun =
    (lib.evalModules {
      modules = [./devenv.nix (devenvSrc + "/src/modules/tasks.nix") h.stubs taskStubs upstream];
      specialArgs = {inherit pkgs lib;};
    }).config.tasks."devenv:git-hooks:run";
in
  assay.suite "devenv-modules-devenv" {
    importsEveryFeature = assay.eq (h.optionNames ./devenv.nix) features;
    # Importing must not switch anything on: the root devenv.nix opts in feature by feature.
    featuresOffByDefault = assay.eq (map (f: cfg.local.features.${f}.enable) features) (map (_: false) features);
    addsNoPackagesWhenOff = assay.eq (h.packageNames cfg) [];
    # Imports are live, not just declared: enabling one feature reaches config.
    enabledFeatureReachesConfig = assay.eq (builtins.elem "moon-cli" moonOn.packages) true;

    importsWithDevenv = assay.eq cfg.local.withDevenv.name "with-devenv";
    importsNoHooksOnShellEntry = assay.eq hookRun.before [];
  }
