# Colocated suite: V-268161 — full ASLR.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268161.nix {};
  config = fixture.evalWith [./V-268160.nix ./V-268161.nix];
in
  assay.suite "stig-V-268161" {
    randomizeVaSpace = assay.eq mod.boot.kernel.sysctl."kernel.randomize_va_space" 2;
    reachesEvaluatedConfig = assay.eq config.boot.kernel.sysctl."kernel.randomize_va_space" 2;

    # Both sysctl controls land together — two modules writing into boot.kernel.sysctl must
    # merge, not clobber.
    composesWithKptrRestrict = assay.eq config.boot.kernel.sysctl."kernel.kptr_restrict" 1;
  }
