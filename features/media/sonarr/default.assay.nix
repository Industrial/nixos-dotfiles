# Colocated suite: sonarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {sonarr = "sonarr";};
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "sonarr" {
    description = assay.eq mod.systemd.services.sonarr.description "Sonarr Daemon";
    systemUser = assay.eq mod.users.users.sonarr.isSystemUser true;
  }
