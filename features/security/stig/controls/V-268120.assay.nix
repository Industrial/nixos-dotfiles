# Colocated suite: V-268120 — audit config files not writable, structurally.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;

  self = import ./V-268120.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268110.nix];
  entries = fixture.etcMatching config "audit/.*";
  names = builtins.attrNames entries;
in
  assay.suite "stig-V-268120" {
    emitsNothing = assay.eq self {};

    auditEtcTreeExists = assay.eq (builtins.length names > 0) true;

    # Not one of them is a mutable copy with its own mode — they are all store symlinks, which
    # is why no chmod is needed or possible.
    noMutableAuditConfigFiles = assay.eq (builtins.all (n: entries.${n}.mode == "symlink") names) true;

    # Named explicitly: this is the file V-268110 writes log_group into, and it must be as
    # immutable as the rest.
    auditdConfIsImmutable = assay.eq entries."audit/auditd.conf".mode "symlink";
  }
