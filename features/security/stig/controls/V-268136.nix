# V-268136 (CAT II) — NixOS must use multifactor authentication for network access to
# privileged accounts.
#
# Fix text: environment.systemPackages = [ pkgs.opencryptoki ];
#
# Note what that does and does not do. opencryptoki is a PKCS#11 implementation — it provides
# the token plumbing MFA needs, and the check greps for the package. It does not by itself
# require a second factor for anything: the PAM side is V-268177 (`security.pam.p11.enable`)
# and the revocation side is V-268179. Installing the package satisfies the published check
# while the actual MFA enforcement lives in its siblings, which is worth recording in the
# report rather than reading this control as "MFA is on".
#
# `full` profile. This fleet already has features/security/yubikey, which is the plausible
# basis for real MFA here; opencryptoki is additive to it.
{pkgs, ...}: {
  environment.systemPackages = [pkgs.opencryptoki];
}
