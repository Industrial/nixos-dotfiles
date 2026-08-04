# Colocated suite: jellyseerr service enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = { jellyseerr = "jellyseerr"; };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "jellyseerr" {
    enabled = assay.eq "${mod}.services.jellyseerr.enable" "true";
    systemUser = assay.eq "${mod}.users.users.jellyseerr.isSystemUser" "true";
  }
