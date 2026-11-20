# Colocated suite for nix/devenv-modules/default.nix.
#
# default.nix is what the root devenv.yaml's `imports: [./nix/devenv-modules]` resolves to.
# It must expose exactly what devenv.nix does — if it drifted to a subset, features enabled in
# the root devenv.nix would fail as unknown options only when a shell is entered.
let
  assay = import ./lib/assay.nix;
  h = import ./lib/feature-eval.nix {};
  cfg = (h.evalModule ./default.nix {}).config;
in
  assay.suite "devenv-modules-default" {
    sameFeaturesAsDevenvNix = assay.eq (h.optionNames ./default.nix) (h.optionNames ./devenv.nix);
    providesWithDevenv = assay.eq cfg.local.withDevenv.name "with-devenv";
    featureEnablesThroughDefault =
      assay.eq (builtins.elem "moon-cli" (h.feature ./default.nix {local.features.program-moon.enable = true;}).packages) true;
  }
