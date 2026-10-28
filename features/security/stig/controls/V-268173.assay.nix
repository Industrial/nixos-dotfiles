# Colocated suite: V-268173 — AppArmor enabled.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268173.nix {};
in
  assay.suite "stig-V-268173" {
    apparmorEnabled = assay.eq mod.security.apparmor.enable true;
  }
