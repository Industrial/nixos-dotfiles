# Colocated suite for devenv.nix — the repo's dev shell, built on the vendored nix/devenv-modules.
#
# devenv.nix is a devenv module: a function of {inputs, pkgs, lib, config}. It is called here
# with the pinned nixpkgs and stand-ins for the flake inputs and for `config.local.withDevenv`,
# and the claims read the attrset it returns. The vendored features' own behaviour is covered by
# their suites under nix/devenv-modules/features; this one pins what the repo asks of them.
#
# The hook wiring is the part with history: hook entries that re-entered `devenv shell`
# recursed without bound (2026-11-18), so every entry must go through the with-devenv wrapper.
let
  assay = import ./common/assay/default.nix;
  nixos = import ./common/assay/nixos.nix;
  lib = nixos.lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  withDevenv = "/stub-with-devenv";
  stub = name: {packages.x86_64-linux.${name} = "stub-${name}";};

  shell = import ./devenv.nix {
    inherit pkgs lib;
    inputs = {
      assay.packages.x86_64-linux = lib.genAttrs ["nixq" "nixdrv" "nixfetch" "nixstore"] (n: "stub-${n}");
      definitively = stub "definitively";
    };
    config.local.withDevenv = withDevenv;
  };

  packageNames = map (p:
    if builtins.isString p
    then p
    else lib.getName p)
  shell.packages;

  hooks = shell.git-hooks.hooks;
  enabledFeatures = builtins.attrNames (lib.filterAttrs (_: f: f.enable) shell.local.features);
in
  assay.suite "devenv" {
    importsTheVendoredModules = assay.eq shell.imports [./nix/devenv-modules];

    enablesTheSharedFeatures = assay.eq enabledFeatures [
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

    # The assay CLI comes from program-assay; its workspace companions are added here, from the
    # assay flake input rather than from nixpkgs.
    shipsAssayCompanionsFromTheInput =
      assay.eq (builtins.all (n: builtins.elem "stub-${n}" packageNames) ["nixq" "nixdrv" "nixfetch" "nixstore"]) true;
    shipsDefinitively = assay.eq (builtins.elem "stub-definitively" packageNames) true;
    shipsNixTestRunners =
      assay.eq (builtins.all (n: builtins.elem n packageNames) ["nix-unit" "namaka" "nixt"]) true;

    allowsUnfree = assay.eq shell.env.NIXPKGS_ALLOW_UNFREE "1";
    # The coverage tools are named from the same llvm the shell installs.
    llvmCovPointsAtTheInstalledLlvm =
      assay.eq shell.env.LLVM_COV "${pkgs.llvmPackages.llvm}/bin/llvm-cov";

    scriptsForThePrekEntryPoints = assay.eq (builtins.attrNames shell.scripts) ["dev" "format" "pre-commit" "pre-push"];
    # bin/dev is the repo's entry point; inside the shell it is `dev`.
    devScriptRunsBinDev = assay.eq shell.scripts.dev.exec ''exec "$DEVENV_ROOT/bin/dev" "$@"'';
    prePushRunsTheFullSuite = assay.eq (lib.hasInfix "moon run dotfiles:test\n" shell.scripts.pre-push.exec) true;
    preCommitRunsOnlyAffected =
      assay.eq (lib.hasInfix "moon run dotfiles:test --affected" shell.scripts.pre-commit.exec) true;

    # Every hook entry runs through the wrapper, never through `devenv shell`.
    everyHookEntryUsesWithDevenv =
      assay.eq
      (lib.mapAttrs (_: h: lib.hasPrefix "${withDevenv}/bin/with-devenv " h.entry)
        (lib.filterAttrs (_: h: h ? entry) hooks))
      {
        deepsec = true;
        moon-test = true;
      };

    # deepsec blocks a push, not a commit (AGENTS.md "Git pre-push").
    deepsecGatesPush = assay.eq [hooks.deepsec.enable hooks.deepsec.stages] [true ["pre-push"]];
    deepsecRunsTheHookScript = assay.eq hooks.deepsec.entry "${withDevenv}/bin/with-devenv bin/git-hooks/deepsec-pre-push";
    affectedTestsGateCommit = assay.eq [hooks.moon-test.enable hooks.moon-test.stages] [true ["pre-commit"]];
    coverageHookIsOff = assay.eq hooks.moon-coverage.enable false;

    # Shell entry must not run hooks (it used to run `prek run -a` and recurse): this file
    # adds no enterShell work and no task wiring of its own, and every enabled hook is a
    # git (commit or push) hook.
    noEnterShell = assay.eq (shell ? enterShell) false;
    noTasks = assay.eq (shell ? tasks) false;
    hookStagesAreGitStages =
      assay.eq
      (lib.all (h: lib.all (s: builtins.elem s ["pre-commit" "pre-push"]) h.stages)
        (lib.attrValues (lib.filterAttrs (_: h: h.enable) hooks)))
      true;
  }
