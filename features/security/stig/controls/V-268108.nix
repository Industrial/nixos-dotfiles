# V-268108 (CAT II) — NixOS audit records must be off-loaded onto a different system or
# storage media from the system being audited.
#
# Fix text configures `services.journald.upload` with four site-specific values written as
# shell-style placeholders ($URL_OF_REMOTE_SERVER, $PATH_TO_CLIENT_PEM_SSL_KEY, …) that are
# not valid Nix. There is no way to "apply this control literally" — it requires a site
# decision, which is why `security.stig.remoteLogging` has no defaults.
#
# The assertion is the point. A plausible-looking placeholder URL would give a host that
# believes it is shipping audit records somewhere that does not exist, and the report would
# call it compliant. Refusing to build is the honest failure.
#
# `full` profile. Pairs with V-268109, which authenticates the far end.
{
  config,
  lib,
  ...
}: let
  cfg = config.security.stig.remoteLogging;
in {
  assertions = [
    {
      assertion = cfg.url != null;
      message = ''
        V-268108 requires a remote journal endpoint, and there is no safe default for one.
        Set it, or exclude the control with a written justification:

          security.stig.remoteLogging.url = "https://logs.example.com:19532";
          security.stig.remoteLogging.serverCertificateFile = /path/to/client.pem;
          security.stig.remoteLogging.serverKeyFile = /path/to/client.key;
          security.stig.remoteLogging.trustedCertificateFile = /path/to/ca.pem;

        or

          security.stig.exclude."V-268108" = "<why this host does not off-load audit records>";
      '';
    }
  ];

  # `optionalAttrs`, not `mkIf`: both are correct as a NixOS module, but mkIf wraps the whole
  # attrset in a deferred `{_type = "if"; …}` node, which the colocated suite cannot read
  # through without reaching into internals. The condition is on the entire block, so the
  # plain conditional is equivalent and keeps the control testable.
  services.journald.upload = lib.optionalAttrs (cfg.url != null) {
    enable = true;
    settings.Upload = lib.filterAttrs (_: v: v != null) {
      URL = cfg.url;
      ServerCertificateFile = cfg.serverCertificateFile;
      ServerKeyFile = cfg.serverKeyFile;
      TrustedCertificateFile = cfg.trustedCertificateFile;
    };
  };
}
