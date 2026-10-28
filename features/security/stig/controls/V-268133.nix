# V-268133 (CAT II) — NixOS must enforce a 180-day maximum password lifetime restriction.
#
# Fix text: security.loginDefs.settings.PASS_MAX_DAYS = "180";
#
# `full` profile: forces password expiry every 180 days. On a personal workstation that is a
# recurring interruption, and current guidance (NIST SP 800-63B) argues against forced
# rotation — but the control is explicit, so it is implemented as written and the tension is
# recorded here rather than resolved unilaterally.
{...}: {
  security.loginDefs.settings.PASS_MAX_DAYS = "180";
}
