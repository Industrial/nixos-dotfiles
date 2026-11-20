# Colocated suite for profiles/development.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.development.enable = true;}];});
  has = f: builtins.elem f on;
in
  assay.suite "development" {
    enablesGit = assay.eq (has "programming.git") true;
    enablesNeovim = assay.eq (has "programming.neovim") true;
    enablesDevenv = assay.eq (has "programming.devenv") true;
    # cursor and vscodium are kept in step (845101f3 reinstated VSCodium to mirror cursor).
    editorsMirrored = assay.eq (has "programming.cursor" && has "programming.vscodium") true;
  }
