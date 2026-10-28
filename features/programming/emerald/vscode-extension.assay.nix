# Colocated suite for features/programming/emerald/vscode-extension.nix.
# String-level guards (repo pattern): identity, pinned npm closure, and the passthru metadata
# the VSCode extension machinery needs.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./vscode-extension.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "emerald-vscode-extension" {
    namesExtension = assay.eq (has ".*pname = \"vscode-emerald-lang\";.*") true;

    # Built from the emerald flake input's editors/vscode, not from a marketplace — Emerald is
    # not published there, so a marketplace fetcher would be a dead end.
    buildsFromFlakeInput = assay.eq (has ".*src = .*inputs\\.emerald.*/editors/vscode.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-yySxi9z6n4xdGuE54cdM58Yt/tKGo4gCwhgl559V/8Q=\";.*") true;

    # Unlike the prebuilt npm tarballs elsewhere in this repo, this one must actually build.
    runsNpmBuild = assay.eq (has ".*dontNpmBuild = false;.*") true;
    usesBuildScript = assay.eq (has ".*npmBuildScript = \"build\";.*") true;

    # libsecret is needed at build time; without it the native module fails to configure.
    buildsAgainstLibsecret = assay.eq (has ".*libsecret.*") true;

    # The extension must land where VSCode/Cursor look, with the publisher-qualified id.
    installsToExtensionsDir = assay.eq (has ".*share/vscode/extensions/emerald-lang\\.emerald-lang.*") true;
    declaresUniqueId = assay.eq (has ".*vscodeExtUniqueId = \"emerald-lang\\.emerald-lang\";.*") true;
    declaresPublisher = assay.eq (has ".*vscodeExtPublisher = \"emerald-lang\";.*") true;

    # Grammar and language config are part of the shipped extension, not just dist/.
    shipsSyntaxes = assay.eq (has ".*cp -r syntaxes.*") true;
    shipsLanguageConfiguration = assay.eq (has ".*language-configuration\\.json.*") true;
  }
