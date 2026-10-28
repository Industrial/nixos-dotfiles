# V-268175 (CAT II) — NixOS must employ approved cryptographic hashing algorithms for all
# stored passwords.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test.
#
# The fix text is not configuration at all — it is remediation:
#
#   Lock all interactive user accounts not using SHA-512 hashing until the passwords can be
#   regenerated with SHA-512.
#   $ sudo usermod -L $USERNAME
#
# And the check reads the hash field of an existing account:
#
#   $ sudo cat /etc/shadow | grep "<username>" | cut -d'$' -f2
#   If the command does not return 6 for SHA512, this is a finding.
#
# So this control is about the hashes **already stored**, which no amount of configuration can
# assert. V-268130 sets ENCRYPT_METHOD=SHA512 so every *new* password is SHA-512, but an
# account whose password predates that setting keeps its old hash until it is changed.
#
# Registered in `security.stig.deferredVerification`: the VM test reads /etc/shadow and
# asserts field 2 is `6` for every interactive account.
{...}: {
  # Intentionally empty — see above and ./V-268175.assay.nix.
}
