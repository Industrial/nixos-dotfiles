# Colocated suite for nix/devenv-modules/lib/feature-eval.nix.
#
# Every nix/devenv-modules/features/*.assay.nix suite reads its feature through this helper, so
# if the stubs or the projection lied, those suites would pass for the wrong reason. The claims
# here run the helper on a synthetic feature whose config is known exactly, and pin the merge
# behaviour the stubs promise: typed options honour mkBefore / mkForce like devenv's do, and
# freeform keys are accepted rather than requiring an inventory of every devenv option.
let
  assay = import ./assay.nix;
  h = import ./feature-eval.nix {};
  inherit (h) lib pkgs;

  probe = builtins.toFile "probe-feature.nix" ''
    {lib, config, pkgs, ...}: {
      options.local.features.probe.enable = lib.mkEnableOption "probe";
      config = lib.mkIf config.local.features.probe.enable {
        packages = [pkgs.hello];
        env.PROBE = "1";
        enterShell = "echo probe";
        scripts.probe-run.exec = "probe --run";
        languages.rust = {
          enable = true;
          channel = "stable";
        };
      };
    }
  '';
  enable = {local.features.probe.enable = true;};

  off = h.feature probe {};
  on = h.feature probe enable;
  merged = h.feature probe {
    imports = [enable];
    packages = [pkgs.jq];
    env.PROBE = lib.mkForce "2";
    enterShell = lib.mkBefore "echo first";
  };
  freeform = (h.evalModule probe {someUnknownTopLevel.x = 1;}).config;
in
  assay.suite "feature-eval" {
    disabledProjectsEmpty = assay.eq {inherit (off) packages scripts env enterShell;} {
      packages = [];
      scripts = [];
      env = {};
      enterShell = "";
    };
    missingLanguagesDefaultOff = assay.eq [off.languages.python.enable off.languages.javascript.enable] [false false];

    projectsPackageNames = assay.eq on.packages ["hello"];
    projectsEnv = assay.eq on.env {PROBE = "1";};
    projectsScriptNames = assay.eq on.scripts ["probe-run"];
    projectsScriptExec = assay.eq on.scriptExec.probe-run "probe --run";
    projectsRustWithDefaults = assay.eq on.languages.rust {
      enable = true;
      channel = "stable";
      version = "";
      components = [];
      targets = [];
    };

    optionNamesListsFeatures = assay.eq (h.optionNames probe) ["probe"];

    # Merge-sensitive surfaces behave as in devenv: lists concatenate across modules, mkForce
    # wins, mkBefore orders shell fragments.
    packagesConcatenate = assay.eq (lib.sort lib.lessThan merged.packages) ["hello" "jq"];
    envHonoursMkForce = assay.eq merged.env.PROBE "2";
    enterShellHonoursMkBefore = assay.eq merged.enterShell "echo first\necho probe";

    freeformAcceptsUnknownKeys = assay.eq freeform.someUnknownTopLevel.x 1;
    packageNamesPrefersPname = assay.eq (h.packageNames {
      packages = [
        {
          pname = "p";
          name = "p-1.0";
        }
      ];
    }) ["p"];
  }
