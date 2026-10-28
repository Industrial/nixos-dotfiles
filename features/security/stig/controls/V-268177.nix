# V-268177 (CAT II) — NixOS must implement multifactor authentication for remote access to
# privileged accounts in such a way that one of the factors is provided by a device separate
# from the system gaining access.
#
# Fix text: security.pam.p11.enable = true;
#
# This is the control that actually enforces the second factor, as opposed to V-268136 which
# only installs the PKCS#11 token plumbing. pam_p11 authenticates against a smartcard or
# token — the "separate device" the requirement asks for.
#
# It depends on V-268176 (UsePAM yes, in base-safe) to reach remote sessions at all: without
# PAM in sshd's path, a PAM-side factor covers console logins only.
#
# `full` profile, and the one most likely to lock out a host that has no token enrolled. This
# fleet has features/security/yubikey, which is the plausible enrolment path.
{...}: {
  security.pam.p11.enable = true;
}
