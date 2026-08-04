# Colocated suite: radarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = { radarr = "radarr"; };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "radarr" {
    description = assay.eq "${mod}.systemd.services.radarr.description" ''"Radarr Daemon"'';
    systemUser = assay.eq "${mod}.users.users.radarr.isSystemUser" "true";
  }
