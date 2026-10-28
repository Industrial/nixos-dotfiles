# Colocated suite: V-268107 — kernel audit messages reach the journal.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268107.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268107.nix];
in
  assay.suite "stig-V-268107" {
    auditToJournal = assay.eq mod.services.journald.settings.Journal.Audit true;

    # Declared through the current option name, not the renamed `services.journald.audit`
    # the fix text uses.
    doesNotUseRenamedOption = assay.eq (mod.services.journald ? audit) false;

    reachesEvaluatedConfig = assay.eq config.services.journald.settings.Journal.Audit true;

    # nixpkgs defaults this to "keep", which leaves the kernel's existing forwarding state
    # alone rather than asserting it — so setting it is a real change, not a restatement.
    nixpkgsDefaultIsKeep = assay.eq (fixture.evalWith [./V-268080.nix]).services.journald.settings.Journal.Audit "keep";
  }
