# Colocated suite for profiles/communication.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.communication.enable = true;}];});
in
  assay.suite "communication" {
    exactSet = assay.eq on ["communication.discord" "communication.signal-desktop"];
  }
