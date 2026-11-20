# Assay: Helix, its language servers, and the config it symlinks into place.
#
# Claims read the evaluated config. config.toml and languages.toml are store files the
# activation script links into ~/.config/helix; the suite reads those files back (IFD is fine
# in a suite) and parses them with fromTOML, so the claims are about the TOML Helix actually
# loads -- brackets and all, with no regex escaping to get wrong.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  user = nixos.defaultSettings.username;
  configDir = "${nixos.defaultSettings.userdir}/.config/helix";
  activation = cfg.system.activationScripts.helixConfig.text;
  activationHas = needle: lib.hasInfix needle activation;
  linkedFile = name:
    builtins.fromTOML (builtins.readFile (builtins.head
        (builtins.match ".*ln -sfn (/nix/store/[^ ]+) ${configDir}/${name}\n.*" activation)));
  config = linkedFile "config.toml";
  languages = linkedFile "languages.toml";
  language = name: lib.findFirst (l: l.name == name) null languages.language;
  serversNamed = lib.unique (builtins.concatMap (l: l.language-servers or []) languages.language);
in
  assay.suite "helix" {
    installsHelix = assay.eq (nixos.hasPackage cfg "helix") true;

    # THE claim this feature exists for. rust-analyzer was measured at 4.8 GB across three
    # stray instances on this machine and contributed to OOM kills; the point of trying a
    # lighter editor is not to reintroduce it by the back door, so it must be absent from the
    # closure.
    doesNotInstallRustAnalyzer = assay.eq (nixos.hasPackage cfg "rust-analyzer") false;

    # Rust is pinned to no language server in languages.toml itself, so the policy survives
    # someone later adding rust-analyzer to another feature's closure.
    rustHasNoLanguageServer = assay.eq (language "rust").language-servers [];
    rustAutoFormatOff = assay.eq (language "rust").auto-format false;

    # Every language server named in languages.toml must also be installed, or the editor
    # silently attaches nothing for that language.
    namesExactlyTheseServers = assay.eq serversNamed ["nixd" "taplo" "ruff"];
    installsEveryNamedServer = assay.eq (map (nixos.hasPackage cfg) serversNamed) [true true true];
    installsAlejandra = assay.eq (nixos.hasPackage cfg "alejandra") true;
    nixFormatsWithAlejandra = assay.eq (language "nix").formatter.command "alejandra";
    ruffRunsAsServer = assay.eq languages.language-server.ruff.args ["server"];

    # Inlay hints are a per-keystroke round trip to every attached server.
    inlayHintsOff = assay.eq config.editor.lsp.display-inlay-hints false;
    relativeLineNumbers = assay.eq config.editor.line-number "relative";

    # Config is symlinked from the store, and a pre-existing real file is moved aside rather
    # than clobbered -- the features/cli/tealdeer pattern.
    symlinksConfig = assay.eq (activationHas "ln -sfn /nix/store/") true;
    backsUpExistingConfig = assay.eq (activationHas "mv ${configDir}/$name ${configDir}/$name.backup") true;
    chownsToUser = assay.eq (activationHas "chown -R ${user}:users ${configDir}") true;

    # Setting EDITOR from a feature import is a surprise from the far side; the header says it
    # is left alone, and this keeps that true.
    doesNotSetEditorVariable =
      assay.eq (cfg.environment.variables.EDITOR or null) (nixos.baseline.environment.variables.EDITOR or null);
  }
