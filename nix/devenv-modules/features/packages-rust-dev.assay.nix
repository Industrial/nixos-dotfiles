let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./packages-rust-dev.nix {};
  on = h.feature ./packages-rust-dev.nix {local.features.packages-rust-dev.enable = true;};
  has = name: builtins.elem name on.packages;
in
  assay.suite "packages-rust-dev" {
    disabled = assay.eq off.packages [];
    hasNextest = assay.eq (has "cargo-nextest") true;
    hasSccache = assay.eq (has "sccache") true;
    hasMold = assay.eq (has "mold-unwrapped-wrapper") true;
    hasClangLib = assay.eq (has "clang") true;
    omitsRustc = assay.eq (has "rustc") false;
    omitsClippy = assay.eq (has "clippy") false;
    omitsAnalyzer = assay.eq (has "rust-analyzer") false;
    enterShell = assay.eq (builtins.match ".*sccache.*" on.enterShell != null) true;
    count = assay.eq (builtins.length on.packages) 8;
  }
