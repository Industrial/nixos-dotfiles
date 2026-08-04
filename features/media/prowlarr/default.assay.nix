# Colocated suite: prowlarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = { prowlarr = "prowlarr"; };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "prowlarr" {
    description = assay.eq "${mod}.systemd.services.prowlarr.description" ''"Prowlarr Daemon"'';
    systemUser = assay.eq "${mod}.users.users.prowlarr.isSystemUser" "true";
  }
