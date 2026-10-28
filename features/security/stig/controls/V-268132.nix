# V-268132 (CAT II) — NixOS must enforce 24 hours/one day as the minimum password lifetime.
#
# Fix text: security.loginDefs.settings.PASS_MIN_DAYS = "1";
#
# `full` profile: this blocks changing a password twice in one day, which breaks the
# fix-a-typo-immediately workflow. Combined with V-268133's 180-day expiry it is a real
# operational constraint rather than a paper setting.
{...}: {
  security.loginDefs.settings.PASS_MIN_DAYS = "1";
}
