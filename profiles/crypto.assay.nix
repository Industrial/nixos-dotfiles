# Colocated suite for profiles/crypto.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {modules = [{profiles.crypto.enable = true;}];};
in
  assay.suite "crypto" {
    # Every entry is commented out; enabling the profile must switch nothing on.
    declaresSwitch = assay.eq cfg.profiles.crypto.enable true;
    enablesNothing = assay.eq (features.enabledFeatures cfg) [];
  }
