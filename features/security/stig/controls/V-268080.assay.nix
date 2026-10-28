# Colocated suite: V-268080 — audit daemon and kernel audit both enabled.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268080.nix {};
in
  assay.suite "stig-V-268080" {
    # Both halves, asserted separately: one without the other is the silent-failure case.
    auditdEnabled = assay.eq mod.security.auditd.enable true;
    auditEnabled = assay.eq mod.security.audit.enable true;
  }
