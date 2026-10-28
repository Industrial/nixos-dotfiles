# Colocated suite: V-268107 — kernel audit messages reach the journal.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268107.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268107.nix];
in
  assay.suite "stig-V-268107" {
    journaldAudit = assay.eq mod.services.journald.audit true;
    reachesEvaluatedConfig = assay.eq config.services.journald.audit true;

    # `services.journald.audit` is tri-state, not a bool: the nixpkgs default is "keep", which
    # leaves the kernel's existing audit-forwarding state alone rather than asserting it. So
    # setting `true` is a real change, and the control is not a no-op.
    nixpkgsDefaultIsKeep = assay.eq (fixture.evalWith [./V-268080.nix]).services.journald.audit "keep";
    differsFromDefault = assay.eq (mod.services.journald.audit == "keep") false;
  }
