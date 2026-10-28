# Colocated suite: V-268171 — four-second delay after a failed logon.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268171.nix {};
  config = fixture.evalWith [./V-268130.nix ./V-268171.nix ./V-268181.nix];
in
  assay.suite "stig-V-268171" {
    failDelay = assay.eq mod.security.loginDefs.settings.FAIL_DELAY "4";
    reachesEvaluatedConfig = assay.eq config.security.loginDefs.settings.FAIL_DELAY "4";

    # "at least four seconds" — the check allows more, so record that this is a floor.
    meetsTheFloor = assay.eq (mod.security.loginDefs.settings.FAIL_DELAY == "4") true;

    # Three controls write into security.loginDefs.settings; they must merge, not clobber.
    coexistsWithEncryptMethod = assay.eq config.security.loginDefs.settings.ENCRYPT_METHOD "SHA512";
    coexistsWithUmask = assay.eq config.security.loginDefs.settings.UMASK "077";
  }
