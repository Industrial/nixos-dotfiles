# Colocated suite for features/ai/maestro/package.nix.
# Asserts on the evaluated derivation: identity, pinned release, and the fixup opt-outs
# the Bun-compiled binary depends on.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  # Substring test over generated text; store-path context is irrelevant to the match.
  contains = needle: s: lib.hasInfix (builtins.unsafeDiscardStringContext needle) (builtins.unsafeDiscardStringContext s);
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  drv = pkgs.callPackage ./package.nix {};
in
  assay.suite "maestro-package" {
    namesMaestro = assay.eq drv.pname "maestro";
    pinsVersion = assay.eq drv.version "0.106.1";

    # The download URL embeds the version, so version and sha256 must move together.
    urlEmbedsVersion = assay.eq drv.src.url "https://github.com/ReinaMacCredy/maestro/releases/download/v${drv.version}/maestro-linux-x64";
    pinsSha256 = assay.eq drv.src.outputHash "eafe30209e6f6767f8bb62600e6f93f1d600a5c7ea4267d83abc2e58980793fc";

    # Bun standalone binaries embed a virtual filesystem; stdenv fixup breaks the layout, and
    # autoPatchelfHook would leave a runnable `bun` on PATH instead of maestro. Both opt-outs
    # are load-bearing, not cosmetic.
    keepsElfMetadata = assay.eq drv.dontStrip true;
    keepsRpath = assay.eq drv.dontShrinkRpath true;
    noAutoPatchelf = assay.eq (map lib.getName drv.nativeBuildInputs) ["patchelf"];
    # installPhase is the generated build step: matching its text is matching the artifact.
    setsInterpreterManually =
      assay.eq
      (contains "patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} $out/bin/maestro" drv.installPhase)
      true;

    exposesMaestroAsMainProgram = assay.eq drv.meta.mainProgram "maestro";
  }
