# Colocated suite: programs.appimage enable + binfmt.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {};
in
  assay.suite "appimage" {
    enabled = assay.eq mod.programs.appimage.enable true;
    binfmt = assay.eq mod.programs.appimage.binfmt true;
  }
