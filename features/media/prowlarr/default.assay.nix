# Colocated suite: prowlarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
      pkgs = { prowlarr = "prowlarr"; };
    in import ./default.nix { inherit pkgs; };

in
  assay.suite "prowlarr" {
    description = assay.eq mod.systemd.services.prowlarr.description "Prowlarr Daemon";
    systemUser = assay.eq mod.users.users.prowlarr.isSystemUser true;
  }
