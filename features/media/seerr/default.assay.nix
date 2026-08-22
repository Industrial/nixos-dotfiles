# Colocated suite: seerr service enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod =
    let
      pkgs = {seerr = "seerr";};
    in
      import ./default.nix {
        inherit pkgs;
        config = {};
        lib = {};
      };
in
  assay.suite "seerr" {
    enabled = assay.eq mod.services.seerr.enable true;
    systemUser = assay.eq mod.users.users.seerr.isSystemUser true;
  }
