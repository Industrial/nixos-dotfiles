let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./program-assay.nix {};
  on = h.feature ./program-assay.nix {local.features.program-assay.enable = true;};
  noDogfood = h.feature ./program-assay.nix {
    local.features.program-assay = {
      enable = true;
      dogfood = false;
    };
  };
  flake = h.feature ./program-assay.nix {
    local.features.program-assay = {
      enable = true;
      releaseHash = null;
    };
  };
  has = name: names: builtins.elem name names;
in
  assay.suite "program-assay" {
    disabled = assay.eq off.packages [];
    hasBinary = assay.eq (has "assay" on.packages) true;
    hasNix = assay.eq (has "nix" on.packages) true;
    dogfoodScript = assay.eq (has "assay-dogfood" on.scripts) true;
    dogfoodRunsNixTree = assay.eq (builtins.match ".*assay run.*" on.scriptExec.assay-dogfood != null) true;
    noDogfoodOmitsScript = assay.eq (has "assay-dogfood" noDogfood.scripts) false;
    flakeStillAssay = assay.eq (has "assay" flake.packages) true;
  }
