# Colocated suite: readarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
      pkgs = { readarr = "readarr"; };
    in import ./default.nix { inherit pkgs; };

in
  assay.suite "readarr" {
    description = assay.eq mod.systemd.services.readarr.description "Readarr Daemon";
    systemUser = assay.eq mod.users.users.readarr.isSystemUser true;
  }
