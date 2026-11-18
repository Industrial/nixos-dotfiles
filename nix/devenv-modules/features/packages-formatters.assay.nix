let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./packages-formatters.nix {};
  on = h.feature ./packages-formatters.nix {local.features.packages-formatters.enable = true;};
  has = name: builtins.elem name on.packages;
in
  assay.suite "packages-formatters" {
    disabled = assay.eq off.packages [];
    hasAlejandra = assay.eq (has "alejandra") true;
    hasTreefmt = assay.eq (has "treefmt") true;
    hasBiome = assay.eq (has "biome") true;
    hasTaplo = assay.eq (has "taplo") true;
    omitsRustfmt = assay.eq (has "rustfmt") false;
    count = assay.eq (builtins.length on.packages) 9;
  }
