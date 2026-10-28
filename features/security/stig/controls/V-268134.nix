# V-268134 (CAT II) — NixOS must enforce a minimum 15-character password length.
#
# Fix text writes minlen=15 into the same /etc/security/pwquality.conf that six base-safe
# controls share, via the same broken `environment.etc."/security/pwquality.conf".text`
# pattern (list assigned to a str option, and a leading slash). Contributed through
# `security.stig.pwquality` like the rest, so it merges instead of colliding.
#
# `full` profile: a 15-character minimum invalidates any shorter existing password at its next
# change.
#
# This is also the control that makes V-268129's difok=8 mean what its requirement says. On
# its own, difok=8 is an absolute count of changed characters; only alongside a 15-character
# minimum is it "at least 50 percent". V-268129 is in base-safe and this one is not, so on a
# workstation that pairing is incomplete by design — recorded in V-268129 and asserted here.
{...}: {
  security.stig.pwquality.minlen = 15;
}
