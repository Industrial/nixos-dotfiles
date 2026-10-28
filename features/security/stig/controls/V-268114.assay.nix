# Colocated suite: V-268114 — audit log file 0600 root:root via tmpfiles.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268114.nix {};
  rule = builtins.head mod.systemd.tmpfiles.rules;
  fields = builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
in
  assay.suite "stig-V-268114" {
    rules = assay.eq mod.systemd.tmpfiles.rules ["z /var/log/audit/audit.log 0600 root root -"];

    # `z` adjusts an existing path. `f` or `d` here would have tmpfiles create the log file,
    # racing auditd for ownership of its own log.
    adjustsRatherThanCreates = assay.eq (builtins.elemAt fields 0) "z";
    targetsAuditLog = assay.eq (builtins.elemAt fields 1) "/var/log/audit/audit.log";
    mode0600 = assay.eq (builtins.elemAt fields 2) "0600";
    ownerRoot = assay.eq (builtins.elemAt fields 3) "root";
    groupRoot = assay.eq (builtins.elemAt fields 4) "root";

    exactlyOneRule = assay.eq (builtins.length mod.systemd.tmpfiles.rules) 1;
  }
