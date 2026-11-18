let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./packages-base.nix {};
  on = h.feature ./packages-base.nix {local.features.packages-base.enable = true;};
  has = name: builtins.elem name on.packages;
in
  assay.suite "packages-base" {
    disabled = assay.eq off.packages [];
    hasGit = assay.eq (has "git") true;
    hasPrek = assay.eq (has "prek") true;
    hasJq = assay.eq (has "jq") true;
    hasDirenv = assay.eq (has "direnv") true;
    hasGh = assay.eq (has "gh") true;
    hasCachix = assay.eq (has "cachix") true;
    hasCmake = assay.eq (has "cmake") true;
    hasCommitizen = assay.eq (has "commitizen") true;
    count = assay.eq (builtins.length on.packages) 11;
  }
