# Colocated suite: whisparr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = { whisparr = "whisparr"; };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "whisparr" {
    description = assay.eq "${mod}.systemd.services.whisparr.description" ''"Whisparr Daemon"'';
    systemUser = assay.eq "${mod}.users.users.whisparr.isSystemUser" "true";
  }
