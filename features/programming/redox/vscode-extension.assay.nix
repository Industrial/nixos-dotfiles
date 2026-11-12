# Colocated suite for features/programming/redox/vscode-extension.nix.
# String-level guards (repo pattern): identity, pinned npm closure, the two
# fields that invert against the Emerald derivation, and the passthru metadata
# the VSCode extension machinery needs.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./vscode-extension.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "redox-vscode-extension" {
    namesExtension = assay.eq (has ".*pname = \"vscode-redox-lang\";.*") true;

    # Built from the redox flake input's editors/vscode, not from a
    # marketplace — Redox is not published there, so a marketplace fetcher
    # would be a dead end.
    buildsFromFlakeInput = assay.eq (has ".*src = .*inputs\\.redox.*/editors/vscode.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-WhyyboeEswhnEisJnt4YQDcZi4jKYQrpzma8oJf1FGw=\";.*") true;

    # Unlike the Emerald extension beside it, this one has nothing to compile:
    # redox plan 49 §1.3 chose plain JavaScript so that a checkout is a working
    # editor. A `build` script here would be a step that does not exist.
    skipsNpmBuild = assay.eq (has ".*dontNpmBuild = true;.*") true;

    # The defect this derivation exists to fix (redox plan 71 §1.2):
    # `src/extension.js` requires `vscode-languageclient/node` at module top
    # level, so the closure must be installed alongside it or `activate`
    # throws and the extension degrades silently to TextMate highlighting.
    shipsTheClientClosure = assay.eq (has ".*cp -r src syntaxes node_modules .*") true;

    # The extension must land where VSCode/Cursor look, with the
    # publisher-qualified id.
    installsToExtensionsDir = assay.eq (has ".*share/vscode/extensions/redox-lang\\.redox.*") true;
    declaresUniqueId = assay.eq (has ".*vscodeExtUniqueId = \"redox-lang\\.redox\";.*") true;
    declaresPublisher = assay.eq (has ".*vscodeExtPublisher = \"redox-lang\";.*") true;
    declaresName = assay.eq (has ".*vscodeExtName = \"redox\";.*") true;
  }
