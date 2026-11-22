# Colocated suite for features/nix/vdeploy/test-key.nix — the throwaway signing key the
# vdeploy VM tests sign their local forge's commits with (GH-221).
#
# Evaluates the derivation only (nothing is generated here): what it is built with and what
# it promises the tests.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  key = import ./test-key.nix {inherit pkgs;};
  script = key.buildCommand;
in
  assay.suite "vdeploy-test-key" {
    named = assay.eq key.name "vdeploy-test-signing-key";
    builtWithGnupg = assay.eq (builtins.any (d: lib.hasPrefix "gnupg" (d.pname or d.name or "")) key.nativeBuildInputs) true;
    # A signing-only ed25519 key with no passphrase, generated at build time: nothing secret
    # is checked in, and the VM signs without a pinentry.
    generatedNotCheckedIn = assay.eq (lib.hasInfix "--quick-generate-key" script && lib.hasInfix "ed25519 sign never" script && lib.hasInfix "--passphrase \"\"" script) true;
    # What the VM tests read: the public key (trustedSigningKeys), the secret key (to sign),
    # and the fingerprint (git's user.signingkey).
    providesWhatTheTestsRead =
      assay.eq (map (f: lib.hasInfix "$out/${f}" script) ["public.asc" "secret.asc" "fingerprint"]) [true true true];
    usedByBothSigningTests =
      assay.eq (map (t: lib.hasInfix "test-key.nix" (builtins.readFile t)) [./test.nix ./test-wake.nix]) [true true];
  }
