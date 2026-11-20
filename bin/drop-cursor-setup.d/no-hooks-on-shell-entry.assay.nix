# Colocated suite for bin/drop-cursor-setup.d/no-hooks-on-shell-entry.nix.
#
# The template `bin/drop-cursor-setup --apply` copies verbatim into another repo's
# nix/devenv-modules/ (step 2, "hooks"). It is a real devenv module and the copy is what runs
# there, so it is evaluated here exactly as the vendored copy is.
#
# devenv's git-hooks integration declares `devenv:git-hooks:run` (`prek run -a`) as `before
# devenv:enterTest`, and shell entry runs enterShell's dependents, so every `devenv shell` ran
# every hook across the repo — and prek's tree-wide stash with it, under every concurrent
# session (2026-11-18: 16+ prek processes, 153 dirty files reverted). This module cuts that edge.
#
# Evaluated against devenv's real `tasks` option type (src/modules/tasks.nix at the devenv.lock
# revision), so the mkForce is resolved the way devenv resolves it. feature-eval's freeform
# stubs alone would leave the override unmerged. The upstream definition below mirrors
# devenv's src/modules/integrations/git-hooks.nix; that integration needs the whole git-hooks
# input to evaluate, so it is restated rather than imported.
let
  assay = import ../../common/assay/default.nix;
  h = import ../../nix/devenv-modules/lib/feature-eval.nix {};
  inherit (h) lib pkgs;

  lock = builtins.fromJSON (builtins.readFile ../../devenv.lock);
  devenvSrc = builtins.fetchTree (removeAttrs lock.nodes.devenv.locked ["dir"]);

  # Declared (not freeform) stand-ins for the devenv options tasks.nix writes to; freeform
  # names resolved through `config` recurse back into tasks.nix.
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
  upstream = {
    tasks."devenv:git-hooks:run" = {
      exec = "prek run -a";
      after = ["devenv:git-hooks:install"];
      before = ["devenv:enterTest"];
    };
  };
  task = mods:
    (lib.evalModules {
      modules = [(devenvSrc + "/src/modules/tasks.nix") h.stubs taskStubs upstream] ++ mods;
      specialArgs = {inherit pkgs lib;};
    }).config.tasks."devenv:git-hooks:run";

  without = task [];
  with' = task [./no-hooks-on-shell-entry.nix];
in
  assay.suite "drop-cursor-setup-no-hooks-on-shell-entry" {
    # Control: without this module the hook run is pulled in ahead of enterTest.
    upstreamRunsBeforeEnterTest = assay.eq without.before ["devenv:enterTest"];

    hookRunNotBeforeAnything = assay.eq with'.before [];
    # Only the shell-entry edge is cut: `prek run -a` stays available as a task, still ordered
    # after the hook install.
    hookRunStillDefined = assay.eq with'.exec "prek run -a";
    hookRunStillAfterInstall = assay.eq with'.after ["devenv:git-hooks:install"];
  }
