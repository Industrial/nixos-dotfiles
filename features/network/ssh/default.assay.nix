# Colocated suite: openssh enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''(import ${modFile} {}) '';
in
  assay.suite "ssh" {
    enabled = assay.eq "${mod}.services.openssh.enable" "true";
  }
