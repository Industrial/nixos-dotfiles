# V-268178 (CAT II) — NixOS must prohibit the use of cached authenticators after one day.
#
# The fix text is only a note: "The entire sssd.conf must be entered in this option." No
# option name, no setting, no value — the control's actual requirement
# (`offline_credentials_expiration = 1` in sssd.conf) appears nowhere in the fix text.
#
# The setting lives in the SSSD configuration, which is site input shared with V-268124, so
# this control asserts that configuration exists AND that it sets the expiry. Asserting the
# mere presence of sssd.conf would let a configuration through that caches credentials
# forever, which is the finding.
#
# `full` profile. Disruptive in a specific way worth knowing: with cached credentials expiring
# after a day, a laptop that spends longer than that away from the identity provider cannot
# log in at all.
{
  config,
  lib,
  ...
}: let
  sssdConfig = config.security.stig.sssdConfig;
  setsExpiry =
    sssdConfig
    != null
    && builtins.match ".*offline_credentials_expiration *= *1.*" sssdConfig != null;
in {
  assertions = [
    {
      assertion = sssdConfig == null || setsExpiry;
      message = ''
        V-268178: security.stig.sssdConfig is set but does not expire cached credentials after
        one day, so an offline host could authenticate indefinitely from its cache. Add to the
        [pam] section:

          offline_credentials_expiration = 1

        The published fix text for this control contains only the note "The entire sssd.conf
        must be entered in this option" and never names the setting.
      '';
    }
    {
      assertion = sssdConfig != null;
      message = ''
        V-268178 requires SSSD, whose configuration is site input:

          security.stig.sssdConfig = "<the entire sssd.conf, including offline_credentials_expiration = 1>";

        or exclude the control:

          security.stig.exclude."V-268178" = "<why this host has no cached authenticators>";
      '';
    }
  ];

  services.sssd = lib.optionalAttrs setsExpiry {
    enable = true;
    config = sssdConfig;
  };
}
