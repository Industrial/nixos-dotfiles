# Colocated suite: V-268108 — audit records off-loaded to a remote system.
#
# Both directions matter: with no endpoint configured the control must REFUSE to build, and
# with one configured it must actually wire up journald upload. A control that silently did
# nothing when unconfigured is the failure mode this suite exists to prevent.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = remoteLogging:
    import ./V-268108.nix {
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

  unset = control {};
  configured = control {
    url = "https://logs.example.com:19532";
    trustedCertificateFile = "/run/secrets/ca.pem";
  };

  verdict = mod: (builtins.head mod.assertions).assertion;
in
  assay.suite "stig-V-268108" {
    # Unconfigured must fail the build, not quietly no-op.
    refusesWithoutAnEndpoint = assay.eq (verdict unset) false;
    messageOffersBothPaths =
      assay.eq (builtins.match ".*security\\.stig\\.exclude.*" (builtins.head unset.assertions).message != null) true;
    messageShowsTheOptionNames =
      assay.eq (builtins.match ".*remoteLogging\\.url.*" (builtins.head unset.assertions).message != null) true;

    # Configured must pass and carry the endpoint through.
    acceptsAnEndpoint = assay.eq (verdict configured) true;
    uploadsToTheConfiguredUrl =
      assay.eq configured.services.journald.upload.settings.Upload.URL "https://logs.example.com:19532";
    carriesTheCaBundle =
      assay.eq configured.services.journald.upload.settings.Upload.TrustedCertificateFile "/run/secrets/ca.pem";

    # Unset optional paths are dropped rather than emitted as nulls, which journald would
    # render as empty settings.
    omitsUnsetCertificatePaths =
      assay.eq (configured.services.journald.upload.settings.Upload ? ServerKeyFile) false;
  }
