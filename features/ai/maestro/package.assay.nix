# Colocated suite for features/ai/maestro/package.nix.
# String-level guards (repo pattern): identity, pinned release, and the fixup opt-outs the
# Bun-compiled binary depends on.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "maestro-package" {
    namesMaestro = assay.eq (has ".*pname = \"maestro\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"0\\.106\\.1\";.*") true;

    # The download URL embeds the version, so version and sha256 must move together.
    # Wildcards rather than escaped braces: Nix's regex engine rejects \{ and \[.
    urlEmbedsVersion = assay.eq (has ".*releases/download/v.*version.*/maestro-linux-x64.*") true;
    pinsSha256 = assay.eq (has ".*sha256 = \"eafe30209e6f6767f8bb62600e6f93f1d600a5c7ea4267d83abc2e58980793fc\";.*") true;

    # Bun standalone binaries embed a virtual filesystem; stdenv fixup breaks the layout, and
    # autoPatchelfHook would leave a runnable `bun` on PATH instead of maestro. Both opt-outs
    # are load-bearing, not cosmetic.
    keepsElfMetadata = assay.eq (has ".*dontStrip = true;.*") true;
    keepsRpath = assay.eq (has ".*dontShrinkRpath = true;.*") true;
    setsInterpreterManually = assay.eq (has ".*patchelf --set-interpreter.*") true;

    exposesMaestroAsMainProgram = assay.eq (has ".*mainProgram = \"maestro\";.*") true;
  }
