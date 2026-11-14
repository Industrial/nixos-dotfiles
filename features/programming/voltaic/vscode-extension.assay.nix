# Colocated suite for features/programming/voltaic/vscode-extension.nix.
# String-level guards (repo pattern): identity, pinned npm closure, the two
# fields that invert against the Emerald derivation, and the passthru metadata
# the VSCode extension machinery needs.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./vscode-extension.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "voltaic-vscode-extension" {
    namesExtension = assay.eq (has ".*pname = \"vscode-voltaic-lang\";.*") true;

    # Built from the voltaic flake input's editors/vscode, not from a
    # marketplace — Voltaic is not published there, so a marketplace fetcher
    # would be a dead end.
    buildsFromFlakeInput = assay.eq (has ".*src = .*inputs\\.voltaic.*/editors/vscode.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-3slypAOmFcJqzRCLR7qXG/IW5q3FpT1not9U0AO\\+1Eg=\";.*") true;

    # Unlike the Emerald extension beside it, this one has nothing to compile:
    # voltaic plan 49 §1.3 chose plain JavaScript so that a checkout is a working
    # editor. A `build` script here would be a step that does not exist.
    skipsNpmBuild = assay.eq (has ".*dontNpmBuild = true;.*") true;

    # The defect this derivation exists to fix (voltaic plan 71 §1.2):
    # `src/extension.js` requires `vscode-languageclient/node` at module top
    # level, so the closure must be installed alongside it or `activate`
    # throws and the extension degrades silently to TextMate highlighting.
    shipsTheClientClosure = assay.eq (has ".*cp -r src syntaxes themes icons node_modules .*") true;

    # Every directory `package.json` declares has to reach the install, and the
    # list grew at 0.1.1 while this derivation kept copying three. Two themes
    # and a language icon were declared and absent, which VSCode reports as
    # theme entries pointing at nothing. Asserted by name so the next addition
    # to `contributes` fails here rather than in an editor.
    shipsTheDeclaredThemes = assay.eq (has ".*cp -r .*themes.*") true;
    shipsTheLanguageIcons = assay.eq (has ".*cp -r .*icons.*") true;

    # The extension must land where VSCode/Cursor look, with the
    # publisher-qualified id.
    installsToExtensionsDir = assay.eq (has ".*share/vscode/extensions/voltaic-lang\\.voltaic.*") true;
    declaresUniqueId = assay.eq (has ".*vscodeExtUniqueId = \"voltaic-lang\\.voltaic\";.*") true;
    declaresPublisher = assay.eq (has ".*vscodeExtPublisher = \"voltaic-lang\";.*") true;
    declaresName = assay.eq (has ".*vscodeExtName = \"voltaic\";.*") true;
  }
