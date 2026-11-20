# Colocated suite for profiles/desktop.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {modules = [{profiles.desktop.enable = true;}];};
  has = f: builtins.elem f (features.enabledFeatures cfg);
in
  assay.suite "desktop" {
    # desktop is what pulls in the seat-bound CLI set (see profiles/cli-desktop.nix).
    enablesCliDesktop = assay.eq cfg.profiles.cli-desktop.enable true;
    enablesHyprland = assay.eq (has "window-manager.hyprland") true;
    enablesStylix = assay.eq (has "window-manager.stylix") true;
  }
