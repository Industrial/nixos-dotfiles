# Colocated suite: generated Nushell vendor autoload.
#
# This module is option-gated, so the suite exercises both states. The facts worth pinning are
# the ones a later wave can break without noticing: the activation-script name other features
# and docs refer to, the four hook filenames whose numeric prefix IS the load order, that each
# hook's content comes from the installed binary's own `init` rather than a committed copy, and
# that the relocated environment.sessionVariables survive the gate being turned off.
let
  assay = import ./../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  src = builtins.readFile ./default.nix;

  eval = shellInit:
    (nixpkgsLib.evalModules {
      modules = [
        ./default.nix
        {
          _module.args = {
            pkgs = import <nixpkgs> {};
            settings = {
              hostname = "h";
              username = "alice";
              userdir = "/home/alice";
            };
          };
          cli.shellInit = shellInit;
        }
        # Minimal stand-ins for the option trees this module reads and writes.
        {
          options.environment.sessionVariables = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
          options.environment.profileRelativeSessionVariables = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {XDG_DATA_DIRS = ["/share"];};
          };
          options.system.activationScripts = nixpkgsLib.mkOption {
            type = nixpkgsLib.types.attrsOf nixpkgsLib.types.unspecified;
            default = {};
          };
        }
      ];
    })
    .config;

  enabled = eval {};
  disabled = eval {enable = false;};
  trimmed = eval {hooks = ["env" "starship"];};

  activation = enabled.system.activationScripts.nushellVendorAutoload.text;
  has = haystack: needle: builtins.match ".*${nixpkgsLib.escapeRegex needle}.*" haystack != null;
in
  assay.suite "shell-init" {
    # On by default: profiles/cli-core.nix imports this for every host, so the import is the
    # opt-in. features/fleet/keepalived is the opposite case and defaults to false.
    enabledByDefault = assay.eq enabled.cli.shellInit.enable true;
    disabledEmitsNoActivation = assay.eq (disabled.system.activationScripts == {}) true;

    # The activation-script name is referred to by bin/update/system and by
    # features/cli/nushell's own comment. Renaming it is a documentation break.
    activationScriptName = assay.eq (enabled.system.activationScripts ? nushellVendorAutoload) true;

    # Nushell only looks in `$nu.data-dir/vendor/autoload`, which is the last and
    # highest-precedence entry of `$nu.vendor-autoload-dirs`. Any other path is dead weight.
    targetsNushellDataDir =
      assay.eq (has activation "/home/alice/.local/share/nushell/vendor/autoload") true;

    # One directory symlink, not a file-by-file copy: dropping a hook has to take its file with
    # it, or Nushell keeps sourcing a generator output nothing generates any more.
    linksWholeDirectory = assay.eq (has activation "ln -sfn") true;

    # Activation runs as root. Without this the user owns none of their own shell state.
    chownsToUser = assay.eq (has activation "chown -h alice:users") true;

    # Every hook filename, with the numeric prefix that fixes the load order.
    hookFilenames =
      assay.eq
      (map (name: nixpkgsLib.hasInfix name src) [
        "00-nixos-env.nu"
        "10-starship.nu"
        "20-zoxide.nu"
        "30-carapace.nu"
        "40-atuin.nu"
      ])
      [true true true true true];

    hooksDefaultToAll =
      assay.eq enabled.cli.shellInit.hooks ["env" "starship" "zoxide" "carapace" "atuin"];
    hooksAreSelectable = assay.eq trimmed.cli.shellInit.hooks ["env" "starship"];

    # The point of the whole feature: content comes from the installed binary's own `init`, so
    # it cannot drift from the binary. A committed copy of this output is the defect
    # features/cli/nushell/starship.nu was.
    runsStarshipInit = assay.eq (nixpkgsLib.hasInfix "/bin/starship init nu" src) true;
    runsZoxideInit = assay.eq (nixpkgsLib.hasInfix "/bin/zoxide init nushell --cmd cd" src) true;
    runsCarapaceInit = assay.eq (nixpkgsLib.hasInfix "/bin/carapace _carapace nushell" src) true;
    runsAtuinInit = assay.eq (nixpkgsLib.hasInfix "/bin/atuin init nu" src) true;

    # Generated at build time, so a renamed subcommand fails the build rather than the prompt.
    generationIsABuildStep = assay.eq (nixpkgsLib.hasInfix "pkgs.runCommand" src) true;
    emptyInitFailsTheBuild = assay.eq (nixpkgsLib.hasInfix "test -s" src) true;

    # carapace bakes $HOME/.config/carapace/bin into the PATH line it emits, so it is the one
    # hook that must run under the real home. Under the scratch HOME the generated file
    # prepended the build sandbox's /build/.config/carapace/bin to every shell's PATH.
    carapaceRunsUnderRealHome =
      assay.eq
      (builtins.match ".*carapace _carapace nushell\";\n *home = settings.userdir;.*" src != null)
      true;

    # And the generic guard, because carapace will not be the last tool to do this.
    buildFailsOnSandboxLeak = assay.eq (nixpkgsLib.hasInfix "leaked the build sandbox path" src) true;

    # Relocated here from features/cli/fish, which had no claim on a global attribute. Declared
    # outside the enable gate: these are the host's variables, not this generator's.
    ownsSessionVariables = assay.subset enabled.environment.sessionVariables {
      EDITOR = "nvim";
      GIT_EDITOR = "nvim";
      DIFFPROG = "nvim -d";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
    sessionVariablesSurviveDisable = assay.eq disabled.environment.sessionVariables.EDITOR "nvim";
  }
