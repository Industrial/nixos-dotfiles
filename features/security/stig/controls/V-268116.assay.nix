# Colocated suite: V-268116 — deferred, and registered as deferred.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268116.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268116" {
    emitsNothing = assay.eq self {};
    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268116" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268116" or "") > 20) true;
  }
