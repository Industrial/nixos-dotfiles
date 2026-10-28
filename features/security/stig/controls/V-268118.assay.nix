# Colocated suite: V-268118 — deferred, and registered as deferred.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268118.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268118" {
    emitsNothing = assay.eq self {};
    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268118" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268118" or "") > 20) true;
  }
