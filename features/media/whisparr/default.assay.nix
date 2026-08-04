# Colocated suite: whisparr systemd unit description.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {whisparr = "whisparr";};
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "whisparr" {
    description = assay.eq mod.systemd.services.whisparr.description "Whisparr Daemon";
    systemUser = assay.eq mod.users.users.whisparr.isSystemUser true;
  }
