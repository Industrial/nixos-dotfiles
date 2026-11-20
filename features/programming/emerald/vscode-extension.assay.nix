# Assay: the Emerald VSCode/Cursor extension derivation (vscode-extension.nix).
#
# The derivation is called the way cursor/ and vscodium/ call it -- real pinned pkgs, real
# flake inputs -- and projected to its attributes, never compared whole. The install phase
# is a build script, so matching it as text is matching the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  inputs = nixos.flakeInputs;
  drv = import ./vscode-extension.nix {inherit inputs pkgs;};
  installHas = needle: lib.hasInfix needle drv.installPhase;
in
  assay.suite "emerald-vscode-extension" {
    namesExtension = assay.eq drv.pname "vscode-emerald-lang";

    # Built from the emerald flake input's editors/vscode, not from a marketplace -- Emerald is
    # not published there, so a marketplace fetcher would be a dead end.
    buildsFromFlakeInput = assay.eq drv.src "${inputs.emerald}/editors/vscode";
    pinsNpmDepsHash = assay.eq drv.npmDepsHash "sha256-yySxi9z6n4xdGuE54cdM58Yt/tKGo4gCwhgl559V/8Q=";

    # Unlike the prebuilt npm tarballs elsewhere in this repo, this one must actually build.
    runsNpmBuild = assay.eq drv.dontNpmBuild false;
    usesBuildScript = assay.eq drv.npmBuildScript "build";

    # libsecret is needed at build time; without it the native module fails to configure.
    buildsAgainstLibsecret = assay.eq (builtins.elem "libsecret" (map lib.getName drv.buildInputs)) true;

    # The extension must land where VSCode/Cursor look, with the publisher-qualified id.
    installsToExtensionsDir = assay.eq (installHas "dir=$out/share/vscode/extensions/emerald-lang.emerald-lang") true;
    declaresUniqueId = assay.eq drv.vscodeExtUniqueId "emerald-lang.emerald-lang";
    declaresPublisher = assay.eq drv.vscodeExtPublisher "emerald-lang";
    declaresName = assay.eq drv.vscodeExtName "emerald-lang";

    # Grammar and language config are part of the shipped extension, not just dist/.
    shipsDist = assay.eq (installHas ''cp -r dist "$dir/"'') true;
    shipsSyntaxes = assay.eq (installHas ''cp -r syntaxes "$dir/"'') true;
    shipsLanguageConfiguration = assay.eq (installHas ''cp package.json language-configuration.json "$dir/"'') true;
  }
