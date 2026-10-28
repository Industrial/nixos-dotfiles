# Colocated suite: V-268117 — deferred, and registered as deferred.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268117.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268117" {
    emitsNothing = assay.eq self {};
    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268117" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268117" or "") > 20) true;
  }
