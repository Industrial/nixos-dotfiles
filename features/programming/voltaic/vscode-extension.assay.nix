# Assay: the Voltaic VSCode/Cursor extension derivation (vscode-extension.nix).
#
# The derivation is called the way cursor/ and vscodium/ call it -- real pinned pkgs, real
# flake inputs -- and projected to its attributes, never compared whole: identity, the pinned
# npm closure, the two fields that invert against the Emerald derivation, and the passthru
# metadata the VSCode extension machinery needs. The install phase is a build script, so
# matching it as text is matching the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  inputs = nixos.flakeInputs;
  drv = import ./vscode-extension.nix {inherit inputs pkgs;};
  installHas = needle: lib.hasInfix needle drv.installPhase;
  # The directories the install phase copies recursively, in order.
  copiedDirs = let
    m = builtins.match ''.*cp -r ([^"]+) "\$dir/".*'' drv.installPhase;
  in
    if m == null
    then []
    else lib.splitString " " (builtins.head m);
in
  assay.suite "voltaic-vscode-extension" {
    namesExtension = assay.eq drv.pname "vscode-voltaic-lang";

    # Built from the voltaic flake input's editors/vscode, not from a marketplace -- Voltaic
    # is not published there, so a marketplace fetcher would be a dead end.
    buildsFromFlakeInput = assay.eq drv.src "${inputs.voltaic}/editors/vscode";
    pinsNpmDepsHash = assay.eq drv.npmDepsHash "sha256-3slypAOmFcJqzRCLR7qXG/IW5q3FpT1not9U0AO+1Eg=";

    # Unlike the Emerald extension beside it, this one has nothing to compile: voltaic plan
    # 49 §1.3 chose plain JavaScript so that a checkout is a working editor. A `build` script
    # here would be a step that does not exist.
    skipsNpmBuild = assay.eq drv.dontNpmBuild true;

    # The defect this derivation exists to fix (voltaic plan 71 §1.2): `src/extension.js`
    # requires `vscode-languageclient/node` at module top level, so the closure must be
    # installed alongside it or `activate` throws and the extension degrades silently to
    # TextMate highlighting.
    shipsTheClientClosure = assay.eq (builtins.elem "node_modules" copiedDirs) true;

    # Every directory `package.json` declares has to reach the install, and the list grew at
    # 0.1.1 while this derivation kept copying three. Two themes and a language icon were
    # declared and absent, which VSCode reports as theme entries pointing at nothing.
    # Asserted as the whole list so the next addition to `contributes` is a visible edit.
    copiesEveryDeclaredDirectory = assay.eq copiedDirs ["src" "syntaxes" "themes" "icons" "node_modules"];
    shipsManifestAndReadme = assay.eq (installHas ''cp package.json language-configuration.json README.md "$dir/"'') true;

    # The extension must land where VSCode/Cursor look, with the publisher-qualified id.
    installsToExtensionsDir = assay.eq (installHas "dir=$out/share/vscode/extensions/voltaic-lang.voltaic") true;
    declaresUniqueId = assay.eq drv.vscodeExtUniqueId "voltaic-lang.voltaic";
    declaresPublisher = assay.eq drv.vscodeExtPublisher "voltaic-lang";
    declaresName = assay.eq drv.vscodeExtName "voltaic";
  }
