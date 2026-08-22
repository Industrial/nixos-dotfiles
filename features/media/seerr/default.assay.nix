# Colocated suite: overseerr service enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {overseerr = "overseerr";};
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "overseerr" {
    enabled = assay.eq mod.services.overseerr.enable true;
    systemUser = assay.eq mod.users.users.overseerr.isSystemUser true;
  }
