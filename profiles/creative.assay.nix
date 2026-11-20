# Colocated suite for profiles/creative.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.creative.enable = true;}];});
in
  assay.suite "creative" {
    # Enabled by no host today (every hosts/*/configuration.nix leaves it commented),
    # so this is the only thing keeping its selection honest.
    exactSet = assay.eq on ["creative.gimp" "creative.obs-studio" "creative.openpencil"];
  }
