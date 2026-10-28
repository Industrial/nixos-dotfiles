# Colocated suite: V-268151 — time synchronization enabled.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268151.nix {};
in
  assay.suite "stig-V-268151" {
    timesyncdEnabled = assay.eq mod.services.timesyncd.enable true;
  }
