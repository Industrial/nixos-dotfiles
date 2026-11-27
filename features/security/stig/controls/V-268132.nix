# V-268132 (CAT II) — NixOS must enforce 24 hours/one day as the minimum password lifetime.
#
# Fix text: security.loginDefs.settings.PASS_MIN_DAYS = "1";
#
# `full` profile: this blocks changing a password twice in one day, which breaks the
# fix-a-typo-immediately workflow. Combined with V-268133's 180-day expiry it is a real
# operational constraint rather than a paper setting.
#
# NOT ENFORCED on the pinned system (GH-349): shadow 4.20.3 no longer implements a minimum
# password age. The line below reaches /etc/login.defs and the published check passes, but
# useradd leaves the field empty, and chage and passwd can no longer set it. The test host
# excludes this control for that reason (profiles/test-host.nix, ADR-0008 decision 4), and
# tests/vm/test-host.nix pins the observations. `full` still imports it, as the fix text.
{...}: {
  security.loginDefs.settings.PASS_MIN_DAYS = "1";
}
