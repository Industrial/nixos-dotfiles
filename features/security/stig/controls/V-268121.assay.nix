# Colocated suite: V-268121 — deferred, and registered as deferred.
#
# Also pins the distinction from its neighbours: the files under /etc/audit are provable at
# eval time, the directories containing them are not.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;

  self = import ./V-268121.nix {};
  profile = import ./../profiles/base-safe.nix {};
  deferred = profile.security.stig.deferredVerification;

  config = fixture.evalWith [./V-268080.nix];
  entries = fixture.etcMatching config "audit/.*";
in
  assay.suite "stig-V-268121" {
    emitsNothing = assay.eq self {};
    isRegisteredAsDeferred = assay.eq (builtins.hasAttr "V-268121" deferred) true;
    reasonIsWritten = assay.eq (builtins.stringLength (deferred."V-268121" or "") > 20) true;

    # The directory this control is about is not itself an etc entry — only the files inside
    # it are. That is precisely why the mode cannot be checked here.
    auditDirIsNotAnEtcEntry = assay.eq (builtins.hasAttr "audit" entries) false;
    butItsFilesAre = assay.eq (builtins.hasAttr "audit/auditd.conf" entries) true;
  }
