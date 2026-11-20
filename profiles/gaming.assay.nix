# Colocated suite for profiles/gaming.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.gaming.enable = true;}];});
in
  assay.suite "gaming" {
    # gaming is games and nothing else — it is drakkar-only, so anything else listed
    # here would silently be drakkar-only too.
    onlyGames = assay.eq (builtins.filter (f: builtins.substring 0 6 f != "games.") on) [];
    enablesLutris = assay.eq (builtins.elem "games.lutris" on) true;
  }
