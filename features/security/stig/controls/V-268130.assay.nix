# Colocated suite: V-268130 (CAT I) — passwords hashed with SHA-512.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268130.nix {};
  config = fixture.evalWith [./V-268130.nix];
in
  assay.suite "stig-V-268130" {
    encryptMethod = assay.eq mod.security.loginDefs.settings.ENCRYPT_METHOD "SHA512";
    reachesEvaluatedConfig = assay.eq config.security.loginDefs.settings.ENCRYPT_METHOD "SHA512";

    # Not DES, MD5 or SHA256 — the weaker values this setting also accepts.
    isNotAWeakerMethod = assay.eq (builtins.elem mod.security.loginDefs.settings.ENCRYPT_METHOD ["DES" "MD5" "SHA256"]) false;
  }
