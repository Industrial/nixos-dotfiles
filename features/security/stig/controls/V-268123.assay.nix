# Colocated suite: V-268123 — /etc/audit group-owned by root, structurally.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;

  self = import ./V-268123.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268110.nix];
  entries = fixture.etcMatching config "audit/.*";
  names = builtins.attrNames entries;
in
  assay.suite "stig-V-268123" {
    emitsNothing = assay.eq self {};

    auditEtcTreeExists = assay.eq (builtins.length names > 0) true;
    allGroupOwnedByRoot = assay.eq (builtins.all (n: entries.${n}.group == "+0") names) true;
  }
