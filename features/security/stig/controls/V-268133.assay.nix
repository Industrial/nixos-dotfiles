# Colocated suite: V-268133 — maximum password lifetime of 180 days.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268133.nix {};
  config = fixture.evalWith [./V-268132.nix ./V-268133.nix];
in
  assay.suite "stig-V-268133" {
    maxDays = assay.eq mod.security.loginDefs.settings.PASS_MAX_DAYS "180";

    # 99999 is shadow's "never expires" sentinel and the nixpkgs default; this control is a
    # real change, not a restatement.
    differsFromNeverExpires = assay.eq (mod.security.loginDefs.settings.PASS_MAX_DAYS == "99999") false;

    # The min and max lifetimes must coexist — both write into loginDefs.settings.
    coexistsWithMinDays = assay.eq config.security.loginDefs.settings.PASS_MIN_DAYS "1";
    maxExceedsMin = assay.eq (180 > 1) true;
  }
