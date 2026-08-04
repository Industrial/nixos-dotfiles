# Colocated suite: comin enable + hostname from settings.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "testhost"; username = "alice"; };
    })
  '';
in
  assay.suite "comin" {
    enabled = assay.eq "${mod}.services.comin.enable" "true";
    hostname = assay.eq "${mod}.services.comin.hostname" "\"testhost\"";
    repositorySubdir = assay.eq "${mod}.services.comin.repositorySubdir" "\"hosts/testhost\"";
  }
