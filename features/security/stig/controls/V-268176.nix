# V-268176 (CAT I) — NixOS must employ strong authenticators in the establishment of nonlocal
# maintenance and diagnostic sessions.
#
# The published fix text is wrong twice over:
#
#   openssh.settings.UsePAM = ''yes'';
#
# 1. It is missing the `services.` prefix, so the attribute path does not exist.
# 2. `services.openssh.settings.UsePAM` is declared with `lib.mkEnableOption` (sshd.nix line
#    526), so its type is **bool**. Assigning the string "yes" is a type error, not a
#    stylistic difference.
#
# Corrected to `services.openssh.settings.UsePAM = true`, which is also what the fleet already
# evaluates to. Routing SSH authentication through PAM is what lets the PAM-side controls
# (V-268081 lockout, V-268177 p11/MFA) apply to remote sessions at all — without it those
# controls would silently cover console logins only.
{...}: {
  services.openssh.settings.UsePAM = true;
}
