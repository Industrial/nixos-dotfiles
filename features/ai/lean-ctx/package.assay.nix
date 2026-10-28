# Colocated suite for features/ai/lean-ctx/package.nix.
# String-level guards (repo pattern): identity, pinned release binary, ELF patching.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "lean-ctx-package" {
    namesLeanCtx = assay.eq (has ".*pname = \"lean-ctx\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"3\\.9\\.18\";.*") true;

    # The URL embeds the version, so the two must be bumped together.
    urlEmbedsVersion = assay.eq (has ".*releases/download/v3\\.9\\.18/lean-ctx-x86_64-unknown-linux-gnu\\.tar\\.gz.*") true;
    pinsHash = assay.eq (has ".*hash = \"sha256-jjZ2sqM5TjN4Faj\\+Uqo9VtR/GY/60mbHg\\+uHDnqeZng=\";.*") true;

    # A prebuilt binary, deliberately: nixpkgs' rustc cannot build rten-gemm (AVX512 VNNI
    # intrinsic mismatch). That is why this is fetchurl + autoPatchelfHook, not a source build.
    # Wildcards rather than escaped brackets: Nix's regex engine rejects \[ and \{.
    patchesElf = assay.eq (has ".*nativeBuildInputs = .autoPatchelfHook.;.*") true;
    linksAgainstCxxStdlib = assay.eq (has ".*buildInputs = .stdenv\\.cc\\.cc\\.lib.;.*") true;
    installsSingleBinary = assay.eq (has ".*install -m755 lean-ctx \\$out/bin/lean-ctx.*") true;

    linuxOnly = assay.eq (has ".*platforms = lib\\.platforms\\.linux;.*") true;
  }
