# Colocated suite: V-268160 — kernel pointer restriction at exactly 1.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268160.nix {};
  config = fixture.evalWith [./V-268160.nix];
  value = mod.boot.kernel.sysctl."kernel.kptr_restrict";
in
  assay.suite "stig-V-268160" {
    kptrRestrict = assay.eq value 1;
    reachesEvaluatedConfig = assay.eq config.boot.kernel.sysctl."kernel.kptr_restrict" 1;

    # The check is an equality test, so the stricter value is non-compliant. This case exists
    # to fail loudly if someone raises it to 2 thinking that is an improvement.
    isNotTightenedTo2 = assay.eq (value == 2) false;
    isExactlyOne = assay.eq (builtins.isInt value && value == 1) true;
  }
