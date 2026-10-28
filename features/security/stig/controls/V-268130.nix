# V-268130 (CAT I) — NixOS must store only encrypted representations of passwords.
#
# Fix text: security.loginDefs.settings.ENCRYPT_METHOD = "SHA512";
#
# Already the nixpkgs default, so this costs nothing. Declared anyway because it is CAT I: the
# report should prove the hashing method rather than infer it from a default.
#
# Paired with V-268175, which verifies that the hashes actually *stored* in /etc/shadow are
# SHA-512 — this control sets the method for new passwords, that one checks the existing ones,
# and only a booted machine can answer the second question.
{...}: {
  security.loginDefs.settings.ENCRYPT_METHOD = "SHA512";
}
