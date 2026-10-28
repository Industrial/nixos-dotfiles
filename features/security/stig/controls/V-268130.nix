# V-268130 (CAT I) — NixOS must store only encrypted representations of passwords.
#
# Fix text: security.loginDefs.settings.ENCRYPT_METHOD = "SHA512";
#
# ⚠ APPLYING THIS CONTROL WEAKENS THE SYSTEM. Read before changing it.
#
# nixpkgs defaults ENCRYPT_METHOD to **YESCRYPT**, not SHA512 (verified by evaluating a bare
# system; the colocated suite asserts it so the fact cannot rot). yescrypt is memory-hard and
# is the modern libxcrypt/shadow default; SHA-512 crypt is a fast hash with no memory
# hardness. So setting SHA512 here is a DOWNGRADE from what the distribution ships, applied
# in the name of a CAT I control whose stated requirement — "store only encrypted
# representations of passwords" — yescrypt already satisfies, and satisfies better.
#
# An earlier revision of this file claimed SHA512 was "already the nixpkgs default, so this
# costs nothing". That was asserted without checking and was wrong.
#
# It gets worse in combination with V-268175, whose check reads field 2 of the stored hash and
# requires exactly `6`:
#
#   - muninn's existing `tom` and `root` hashes are `$y$` (yescrypt), so V-268175 reports a
#     finding on a host whose hashing is stronger than the control demands; and
#   - because this control sets ENCRYPT_METHOD, the next password change silently REPLACES
#     those yescrypt hashes with SHA-512, "fixing" the finding by making the system weaker.
#
# This is the same shape as V-268160, where the check is an equality test and the stricter
# value scores as non-compliant — except here the stakes are password storage.
#
# THE DECISION IS THE OPERATOR'S, and it is deliberately left as written compliance for now:
# the control is applied, literally, because it is CAT I and excluding a CAT I control needs
# an explicit human ruling rather than an implementer's preference. To take the other path,
# exclude both controls together with the justification — they are one decision, not two:
#
#   security.stig.exclude = {
#     "V-268130" = "yescrypt (nixpkgs default) exceeds the requirement to store only
#                   encrypted representations; forcing SHA-512 would be a downgrade.";
#     "V-268175" = "Stored hashes are yescrypt, stronger than the SHA-512 the check tests
#                   for. See V-268130.";
#   };
#
# and drop this import from profiles/base-safe.nix.
{...}: {
  security.loginDefs.settings.ENCRYPT_METHOD = "SHA512";
}
