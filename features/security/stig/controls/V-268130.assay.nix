# Colocated suite: V-268130 (CAT I) — passwords hashed with SHA-512.
#
# The load-bearing case here is `nixpkgsDefaultIsYescrypt`. An earlier revision of this
# control asserted SHA512 was "already the nixpkgs default, so this costs nothing" — which was
# never checked and is false. This suite pins the real default so the comment can never drift
# back, and so anyone reading the control sees that applying it is a DOWNGRADE.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268130.nix {};
  config = fixture.evalWith [./V-268130.nix];
in
  assay.suite "stig-V-268130" {
    encryptMethod = assay.eq mod.security.loginDefs.settings.ENCRYPT_METHOD "SHA512";
    reachesEvaluatedConfig = assay.eq config.security.loginDefs.settings.ENCRYPT_METHOD "SHA512";

    # Not DES, MD5 or SHA256 — the weaker methods this setting also accepts.
    isNotAWeakerMethod = assay.eq (builtins.elem mod.security.loginDefs.settings.ENCRYPT_METHOD ["DES" "MD5" "SHA256"]) false;

    # The uncomfortable fact, asserted rather than commented: nixpkgs ships YESCRYPT, which is
    # memory-hard, and this control replaces it with a fast hash. If a future nixpkgs changes
    # its default this case fails and the control's trade-off has to be re-read.
    nixpkgsDefaultIsYescrypt = assay.eq (fixture.evalWith []).security.loginDefs.settings.ENCRYPT_METHOD "YESCRYPT";
    thisControlIsADowngrade = assay.eq (mod.security.loginDefs.settings.ENCRYPT_METHOD != (fixture.evalWith []).security.loginDefs.settings.ENCRYPT_METHOD) true;
  }
