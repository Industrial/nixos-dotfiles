# Colocated suite: jellyseerr service enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
      pkgs = { jellyseerr = "jellyseerr"; };
    in import ./default.nix { inherit pkgs; };

in
  assay.suite "jellyseerr" {
    enabled = assay.eq mod.services.jellyseerr.enable true;
    systemUser = assay.eq mod.users.users.jellyseerr.isSystemUser true;
  }
