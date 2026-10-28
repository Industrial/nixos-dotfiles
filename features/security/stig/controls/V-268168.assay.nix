# Colocated suite: V-268168 (CAT I) — FIPS mode on the kernel command line.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268168.nix {};
  config = fixture.evalWith [./V-268168.nix];
in
  assay.suite "stig-V-268168" {
    setsFipsKernelParam = assay.eq mod.boot.kernelParams ["fips=1"];
    reachesEvaluatedConfig = assay.eq (builtins.elem "fips=1" config.boot.kernelParams) true;

    # Exactly once. boot.kernelParams is a list and this is the only control that sets fips.
    appearsExactlyOnce =
      assay.eq (builtins.length (builtins.filter (p: p == "fips=1") config.boot.kernelParams)) 1;

    # Not in the nixpkgs default command line — this is a real change, and the riskiest one
    # in the benchmark.
    isNotADefault = assay.eq (builtins.elem "fips=1" (fixture.evalWith []).boot.kernelParams) false;

    # A kernel parameter, so it cannot take effect until reboot. The profile that carries it
    # must register that, or the report would claim compliance on a host that merely switched.
    isAKernelParameter = assay.eq (builtins.match "fips=.*" (builtins.head mod.boot.kernelParams) != null) true;
  }
