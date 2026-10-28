# Colocated suite: V-268124 — PKI trust anchor and SSSD.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = stig:
    import ./V-268124.nix {
      lib = nixpkgsLib;
      config.security.stig =
        {
          pkiCaBundle = null;
          sssdConfig = null;
        }
        // stig;
    };

  verdict = mod: (builtins.head mod.assertions).assertion;

  unset = control {};
  bundleOnly = control {pkiCaBundle = "/run/secrets/ca.pem";};
  ready = control {
    pkiCaBundle = "/run/secrets/ca.pem";
    sssdConfig = "[sssd]\ndomains = example.com\n";
  };
in
  assay.suite "stig-V-268124" {
    refusesWithoutInfrastructure = assay.eq (verdict unset) false;
    # Both halves are required: a trust anchor with no SSSD to consume it authenticates
    # nobody.
    refusesWithBundleButNoSssd = assay.eq (verdict bundleOnly) false;
    acceptsWhenBothAreProvided = assay.eq (verdict ready) true;

    # Nothing is emitted while unconfigured, so an incomplete host does not get a
    # half-configured SSSD that breaks logins.
    emitsNoSssdWhenUnset = assay.eq (unset.services.sssd or {}) {};
    enablesSssdWhenReady = assay.eq ready.services.sssd.enable true;
    installsTheTrustAnchor = assay.eq ready.environment.etc."sssd/pki/sssd_auth_ca_db.pem".source "/run/secrets/ca.pem";

    # The message must explain why the published build-time fetch is not used, or someone
    # will "fix" it back.
    messageExplainsTheOmittedFetch =
      assay.eq (builtins.match ".*dl\\.dod\\.cyber\\.mil.*" (builtins.head unset.assertions).message != null) true;
  }
