# Colocated suite: V-268113 — audit log directory 0700 root:root via tmpfiles.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268113.nix {};
  rule = builtins.head mod.systemd.tmpfiles.rules;
  fields = builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
in
  assay.suite "stig-V-268113" {
    rules = assay.eq mod.systemd.tmpfiles.rules ["d /var/log/audit 0700 root root -"];

    # Field-by-field, because a typo in a tmpfiles line fails silently at boot rather than
    # at eval: type / path / mode / user / group.
    isDirectoryRule = assay.eq (builtins.elemAt fields 0) "d";
    targetsAuditDir = assay.eq (builtins.elemAt fields 1) "/var/log/audit";
    mode0700 = assay.eq (builtins.elemAt fields 2) "0700";
    ownerRoot = assay.eq (builtins.elemAt fields 3) "root";
    groupRoot = assay.eq (builtins.elemAt fields 4) "root";

    # "0700 or less permissive" — the check greps for exactly 0700, so do not tighten it.
    exactlyOneRule = assay.eq (builtins.length mod.systemd.tmpfiles.rules) 1;
  }
