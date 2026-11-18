let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./dotenv.nix {};
  on = h.feature ./dotenv.nix {local.features.dotenv.enable = true;};
in
  assay.suite "dotenv" {
    optionName = assay.eq (h.optionNames ./dotenv.nix) ["dotenv"];
    disabled = assay.eq off.dotenv.enable false;
    enabled = assay.eq on.dotenv.enable true;
  }
