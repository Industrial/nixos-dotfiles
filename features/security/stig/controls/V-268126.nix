# V-268126 (CAT II) — NixOS must enforce password complexity by requiring that at least one
# uppercase character be used.
#
# Check: `grep ucredit /etc/security/pwquality.conf`, a finding if the value is positive or
# commented out. So the file content is the compliance; wiring pam_pwquality into PAM is a
# separate control (V-268170), which is why this one is harmless on its own.
#
# Contributed through `security.stig.pwquality` rather than by assigning the etc entry
# directly — see the option's description for why the six published fix texts cannot all be
# applied at once.
#
# `-1` means "require at least one of this class". A positive value would instead grant length
# *credit* for having one, which is the opposite of enforcement and exactly what the check
# rejects.
{...}: {
  security.stig.pwquality.ucredit = -1;
}
