# Colocated suite: V-268132 — minimum password lifetime of one day.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268132.nix {};
in
  assay.suite "stig-V-268132" {
    minDays = assay.eq mod.security.loginDefs.settings.PASS_MIN_DAYS "1";
    # A string, like every other loginDefs setting in this baseline; an int would render
    # differently and the checks grep the rendered file.
    isString = assay.eq (builtins.isString mod.security.loginDefs.settings.PASS_MIN_DAYS) true;
    # 0 would disable the minimum entirely rather than enforce one day.
    isNotZero = assay.eq (mod.security.loginDefs.settings.PASS_MIN_DAYS == "0") false;
  }
