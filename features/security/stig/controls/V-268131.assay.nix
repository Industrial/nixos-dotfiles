# Colocated suite: V-268131 — telnet absent, enforced by assertion.
#
# Both directions are exercised: a clean package set must pass, and a telnet-bearing one must
# fail. Asserting only the happy path would not prove the assertion can fire at all.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = packages:
    import ./V-268131.nix {
      config.environment.systemPackages = packages;
      lib = nixpkgsLib;
    };

  clean = control [];
  withInetutils = control [{pname = "inetutils-2.2";}];
  withBusybox = control [{name = "busybox-1.36.1";}];
  unrelated = control [{pname = "ripgrep";} {pname = "firefox";}];

  verdict = mod: (builtins.head mod.assertions).assertion;
  message = mod: (builtins.head mod.assertions).message;
in
  assay.suite "stig-V-268131" {
    exactlyOneAssertion = assay.eq (builtins.length clean.assertions) 1;

    cleanPackageSetPasses = assay.eq (verdict clean) true;
    unrelatedPackagesPass = assay.eq (verdict unrelated) true;

    # Falsification: the assertion must actually fire.
    inetutilsFails = assay.eq (verdict withInetutils) false;
    busyboxFails = assay.eq (verdict withBusybox) false;

    # The message has to name the offender, or the failure is unactionable.
    messageNamesOffender = assay.eq (builtins.match ".*inetutils-2\\.2.*" (message withInetutils) != null) true;
    messageOffersExclusion = assay.eq (builtins.match ".*security\\.stig\\.exclude.*" (message withInetutils) != null) true;
  }
