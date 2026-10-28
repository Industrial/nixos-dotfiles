# Colocated suite: V-268175 — deferred, and registered as deferred.
#
# Also pins the relationship to V-268130: setting the hashing method is not the same as having
# SHA-512 hashes on disk, and conflating the two would be a false compliance claim.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268175.nix {};
  method = (import ./V-268130.nix {}).security.loginDefs.settings.ENCRYPT_METHOD;
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268175" {
    emitsNothing = assay.eq self {};

    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268175" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268175" or "") > 20) true;

    # New passwords will be SHA-512 (V-268130). Existing stored hashes are the open question,
    # which is exactly why this control is deferred rather than claimed.
    newPasswordsUseSha512 = assay.eq method "SHA512";
  }
