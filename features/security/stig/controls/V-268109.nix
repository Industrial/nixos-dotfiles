# V-268109 (CAT II) — NixOS must authenticate the remote logging server for off-loading audit
# logs.
#
# The fix text is syslog-ng configuration (`destination d_network { syslog(... tls(... ca-file
# ... peer-verify(yes))) }`) and then refers to `services.rsyslogd.extraConfig`. It mixes two
# different log shippers, neither of which this fleet runs: V-268108's own fix text uses
# systemd-journald's upload mechanism, not syslog-ng or rsyslog.
#
# Implemented against the shipper V-268108 actually configures. For journald upload, the
# equivalent of syslog-ng's `peer-verify(yes)` + `ca-file(...)` is TrustedCertificateFile:
# without it journald will upload audit records to whatever answers the URL, which is exactly
# the finding this control describes.
#
# So this control asserts the CA bundle specifically, rather than restating V-268108.
#
# `full` profile.
{
  config,
  lib,
  ...
}: let
  cfg = config.security.stig.remoteLogging;
in {
  assertions = [
    {
      assertion = cfg.url == null || cfg.trustedCertificateFile != null;
      message = ''
        V-268109: audit records are being off-loaded to ${toString cfg.url} without a CA
        bundle, so journald will not authenticate the remote log server. Unauthenticated
        off-load is the finding this control describes.

        Set security.stig.remoteLogging.trustedCertificateFile, or exclude the control with a
        written justification.
      '';
    }
  ];
}
