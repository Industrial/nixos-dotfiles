# Colocated suite: V-268115 — deferred, and registered as deferred.
#
# A verify-only control that nobody registered would silently read as Compliant in the report.
# This suite's real job is to make that impossible.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268115.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;
in
  assay.suite "stig-V-268115" {
    emitsNothing = assay.eq self {};

    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268115" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268115" or "") > 20) true;
  }
