# Colocated suite for features/ai/lean-ctx/package.nix.
# Asserts on the evaluated derivation: identity, pinned release binary, ELF patching.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  drv = pkgs.callPackage ./package.nix {};
in
  assay.suite "lean-ctx-package" {
    namesLeanCtx = assay.eq drv.pname "lean-ctx";
    pinsVersion = assay.eq drv.version "3.9.18";

    # The URL embeds the version, so the two must be bumped together.
    urlEmbedsVersion = assay.eq drv.src.url "https://github.com/yvgude/lean-ctx/releases/download/v${drv.version}/lean-ctx-x86_64-unknown-linux-gnu.tar.gz";
    pinsHash = assay.eq drv.src.outputHash "sha256-jjZ2sqM5TjN4Faj+Uqo9VtR/GY/60mbHg+uHDnqeZng=";

    # A prebuilt binary, deliberately: nixpkgs' rustc cannot build rten-gemm (AVX512 VNNI
    # intrinsic mismatch). That is why this is fetchurl + autoPatchelfHook, not a source build.
    patchesElf = assay.eq (map lib.getName drv.nativeBuildInputs) ["auto-patchelf-hook"];
    linksAgainstCxxStdlib = assay.eq (map (p: p.outPath) drv.buildInputs) [pkgs.stdenv.cc.cc.lib.outPath];
    # installPhase is the generated build step: matching its text is matching the artifact.
    installsSingleBinary = assay.eq (lib.hasInfix "install -m755 lean-ctx $out/bin/lean-ctx" drv.installPhase) true;

    linuxOnly = assay.eq drv.meta.platforms lib.platforms.linux;
  }
