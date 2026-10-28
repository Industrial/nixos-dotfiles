# Colocated suite: V-268122 — /etc/audit owned by root, structurally.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;

  self = import ./V-268122.nix {};
  config = fixture.evalWith [./V-268080.nix ./V-268110.nix];
  entries = fixture.etcMatching config "audit/.*";
  names = builtins.attrNames entries;
in
  assay.suite "stig-V-268122" {
    emitsNothing = assay.eq self {};

    # Sanity: the tree we are making claims about actually exists.
    auditEtcTreeExists = assay.eq (builtins.length names > 0) true;
    includesAuditdConf = assay.eq (builtins.elem "audit/auditd.conf" names) true;

    # Every entry is owned by uid 0.
    allOwnedByRoot = assay.eq (builtins.all (n: entries.${n}.user == "+0") names) true;

    # ...and is a store symlink, so the content is immutable regardless of the link's owner.
    allAreStoreSymlinks = assay.eq (builtins.all (n: entries.${n}.mode == "symlink") names) true;
  }
