# Colocated suite: openssh enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {};

in
  assay.suite "ssh" {
    enabled = assay.eq mod.services.openssh.enable true;
  }
