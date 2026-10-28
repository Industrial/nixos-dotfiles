# Colocated suite: V-268109 — the remote log server is authenticated.
#
# The interesting case is the middle one: an endpoint configured WITHOUT a CA bundle. That is
# a host shipping audit records to an unauthenticated peer while believing it is compliant,
# and it must fail the build.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = remoteLogging:
    import ./V-268109.nix {
      lib = nixpkgsLib;
      config.security.stig.remoteLogging =
        {
          url = null;
          serverCertificateFile = null;
          serverKeyFile = null;
          trustedCertificateFile = null;
        }
        // remoteLogging;
    };

  verdict = mod: (builtins.head mod.assertions).assertion;

  noUpload = control {};
  uploadWithoutCa = control {url = "https://logs.example.com:19532";};
  uploadWithCa = control {
    url = "https://logs.example.com:19532";
    trustedCertificateFile = "/run/secrets/ca.pem";
  };
in
  assay.suite "stig-V-268109" {
    # No off-load configured at all: V-268108 is the control that complains, not this one.
    vacuouslyTrueWithoutUpload = assay.eq (verdict noUpload) true;

    # Off-load WITHOUT authentication is the finding — this is the case that matters.
    refusesUnauthenticatedUpload = assay.eq (verdict uploadWithoutCa) false;
    messageNamesTheEndpoint =
      assay.eq (builtins.match ".*logs\\.example\\.com.*" (builtins.head uploadWithoutCa.assertions).message != null) true;
    # Matched on a fragment that cannot straddle a line break: the message wraps, and `.` in
    # Nix regex does not match a newline.
    messageExplainsTheFinding =
      assay.eq (builtins.match ".*off-load is the finding.*" (builtins.head uploadWithoutCa.assertions).message != null) true;
    messageNamesTheMissingOption =
      assay.eq (builtins.match ".*trustedCertificateFile.*" (builtins.head uploadWithoutCa.assertions).message != null) true;

    acceptsAuthenticatedUpload = assay.eq (verdict uploadWithCa) true;
  }
