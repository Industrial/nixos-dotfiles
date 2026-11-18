# Colocated suite for features/programming/helix
#
# Claims here use lib.hasInfix rather than builtins.match. Nix's regex engine
# rejects `\[` and `\{` outright ("invalid regular expression"), and most of what
# is worth asserting about a TOML config contains brackets — `language-servers =
# []` being the single most important claim in this file. Literal substring
# matching has no escaping rules to get wrong.
let
  assay = import ./../../../common/assay/default.nix;
  lib = (import <nixpkgs> {}).lib;
  src = builtins.readFile ./default.nix;
  hasText = needle: lib.hasInfix needle src;
  mod = import ./default.nix {
    settings = {
      username = "tom";
      userdir = "/home/tom";
    };
    pkgs = {
      writeText = _: text: text;
      helix = "helix";
      nixd = "nixd";
      alejandra = "alejandra";
      taplo = "taplo";
      ruff = "ruff";
    };
  };
  packages = mod.environment.systemPackages;
  activation = mod.system.activationScripts.helixConfig.text;
  activationHas = needle: lib.hasInfix needle activation;
in
  assay.suite "helix" {
    installsHelix = assay.eq (builtins.elem "helix" packages) true;

    # THE claim this feature exists for. rust-analyzer was measured at 4.8 GB
    # across three stray instances on this machine and contributed to OOM kills;
    # the point of trying a lighter editor is not to reintroduce it by the back
    # door, so it must be absent from the closure.
    doesNotInstallRustAnalyzer = assay.eq (builtins.elem "rust-analyzer" packages) false;
    documentsTheRamReason = assay.eq (hasText "4.8 GB") true;

    # Every language server named in languages.toml must also be installed, or the
    # editor silently attaches nothing for that language.
    installsNixd = assay.eq (builtins.elem "nixd" packages) true;
    installsAlejandra = assay.eq (builtins.elem "alejandra" packages) true;
    installsTaplo = assay.eq (builtins.elem "taplo" packages) true;
    installsRuff = assay.eq (builtins.elem "ruff" packages) true;

    # Rust is pinned to no language server in languages.toml itself, so the policy
    # survives someone later adding rust-analyzer to another feature's closure.
    rustHasNoLanguageServer = assay.eq (hasText "language-servers = []") true;
    rustAutoFormatOff = assay.eq (hasText "auto-format = false") true;

    # Inlay hints are a per-keystroke round trip to every attached server.
    inlayHintsOff = assay.eq (hasText "display-inlay-hints = false") true;

    # Config is symlinked from the store, and a pre-existing real file is moved
    # aside rather than clobbered — the features/cli/tealdeer pattern.
    symlinksConfig = assay.eq (activationHas "/home/tom/.config/helix/config.toml") true;
    symlinksLanguages = assay.eq (activationHas "/home/tom/.config/helix/languages.toml") true;
    usesSymlink = assay.eq (activationHas "ln -sfn") true;
    backsUpExistingConfig = assay.eq (activationHas ".backup") true;
    chownsToUser = assay.eq (activationHas "chown -R tom:users") true;

    # Setting EDITOR from a feature import is a surprise from the far side; the
    # header says it is left alone, and this keeps that true.
    doesNotSetEditorVariable = assay.eq (builtins.hasAttr "variables" mod.environment) false;
  }
