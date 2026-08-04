# Colocated suite: lidarr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = { lidarr = "lidarr"; };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "lidarr" {
    description = assay.eq "${mod}.systemd.services.lidarr.description" ''"Lidarr Daemon"'';
    systemUser = assay.eq "${mod}.users.users.lidarr.isSystemUser" "true";
  }
