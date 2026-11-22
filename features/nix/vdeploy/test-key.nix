# A throwaway OpenPGP signing key for the vdeploy VM tests (GH-221). The tests' forge is a
# local repository, so GitHub signs nothing there: the test commits are signed with this key
# instead, and the node trusts it (features.nix.vdeploy.trustedSigningKeys). It has no
# passphrase and signs nothing real; it is generated at build time, never checked in.
#
#   public.asc   the armored public key (trustedSigningKeys)
#   secret.asc   the armored secret key (imported in the VM to sign commits)
#   fingerprint  its fingerprint (git's user.signingkey)
{pkgs}:
pkgs.runCommand "vdeploy-test-signing-key" {nativeBuildInputs = [pkgs.gnupg];} ''
  export GNUPGHOME="$TMPDIR/gnupg"
  mkdir -m 0700 "$GNUPGHOME"
  gpg --batch --pinentry-mode loopback --passphrase "" \
    --quick-generate-key "vdeploy test <vdeploy-test@example.invalid>" ed25519 sign never
  mkdir "$out"
  gpg --batch --armor --export > "$out/public.asc"
  gpg --batch --pinentry-mode loopback --passphrase "" --armor --export-secret-keys > "$out/secret.asc"
  gpg --batch --with-colons --list-keys | awk -F: '/^fpr:/ {print $10; exit}' > "$out/fingerprint"
  gpgconf --kill gpg-agent || true
''
