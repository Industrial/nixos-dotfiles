# Colocated suite: V-268140 — deferred, and registered as deferred.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268140.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268140" {
    emitsNothing = assay.eq self {};
    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268140" deferred) true;
    # The reason must say what the VM test will do, since there is no static list to declare.
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268140" or "") > 20) true;
  }
