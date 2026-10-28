# Colocated suite: V-268179 — locally cached revocation data.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268179.nix {};
  policy = mod.environment.etc."pam_p11/cert_policy".text;
  # Shares the p11 enable with V-268177; identical bools must merge, not conflict.
  config = fixture.evalWith [./V-268177.nix ./V-268179.nix];
in
  assay.suite "stig-V-268179" {
    p11Enabled = assay.eq mod.security.pam.p11.enable true;
    mergesWithV268177 = assay.eq config.security.pam.p11.enable true;

    # crl_auto is THIS control's requirement: cached CRLs so validation survives a network
    # outage. Without it the host can only validate while online.
    cachesRevocationData = assay.eq (builtins.match ".*crl_auto.*" policy != null) true;

    # The other policy elements, which belong to V-268124's path construction.
    checksOcsp = assay.eq (builtins.match ".*ocsp_on.*" policy != null) true;
    validatesTheChain = assay.eq (builtins.match ".*ca.*" policy != null) true;
    verifiesSignatures = assay.eq (builtins.match ".*signature.*" policy != null) true;
  }
