# V-268124 (CAT II) — For PKI-based authentication, NixOS must validate certificates by
# constructing a certification path (including status information) to an accepted trust
# anchor.
#
# The fix text enables SSSD and fetches the DoW PKI CA chain at build time:
#
#   pkgs.fetchzip {
#     url = ".../unclass-certificates_pkcs7_v5-6_DoW.zip";
#     sha256 = "sha256-iwwJRXCnONk/LFddQlwy8KX9e9kVXW/QWDnX5qZFZjc=";
#   }
#
# That fetch is deliberately NOT wired in. A derivation that reaches dl.dod.cyber.mil fails on
# any network that cannot — including CI and this fleet — and it would take the entire system
# closure down with it, turning one control into an unbuildable host. The hash is recorded in
# `security.stig.pkiCaBundle`'s description so an operator can vendor the bundle and verify it.
#
# Both halves are site input: the trust anchor and the SSSD configuration that consumes it.
# The control asserts them rather than shipping an SSSD that cannot authenticate anyone.
#
# `full` profile. One of the six PKI/MFA controls (V-268124, V-268125, V-268135, V-268136,
# V-268177, V-268179) that presuppose identity infrastructure this fleet does not have.
{
  config,
  lib,
  ...
}: let
  cfg = config.security.stig;
  ready = cfg.pkiCaBundle != null && cfg.sssdConfig != null;
in {
  assertions = [
    {
      assertion = ready;
      message = ''
        V-268124 needs PKI infrastructure that cannot be guessed:

          security.stig.pkiCaBundle = /path/to/trust-anchors.pem;
          security.stig.sssdConfig  = "<the entire sssd.conf>";

        The published fix text fetches the DoW CA chain from dl.dod.cyber.mil at build time;
        that is not done here because a host whose closure depends on reaching that URL
        cannot be built on a network without access to it. Vendor the bundle instead — the
        expected sha256 is in the option's description.

        Or exclude the control:

          security.stig.exclude."V-268124" = "<why this host does not do PKI authentication>";
      '';
    }
  ];

  services.sssd = lib.optionalAttrs ready {
    enable = true;
    config = cfg.sssdConfig;
  };

  environment.etc = lib.optionalAttrs ready {
    "sssd/pki/sssd_auth_ca_db.pem".source = cfg.pkiCaBundle;
  };
}
