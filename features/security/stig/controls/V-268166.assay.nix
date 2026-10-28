# Colocated suite: V-268166 — lastlog watched for logon records.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268166.nix {};
  tmpfiles = mod.systemd.tmpfiles.rules;
  fields = fixture.tmpfilesFields (builtins.head tmpfiles);
in
  assay.suite "stig-V-268166" {
    rules = assay.eq mod.security.audit.rules ["-w /var/log/lastlog -p wa -k logins"];
    isWriteAttrWatch = assay.eq (builtins.match "-w .* -p wa -k logins" (builtins.head mod.security.audit.rules) != null) true;

    # auditctl fails the whole rules file if the watch target is missing, so the file must be
    # provisioned alongside the rule.
    provisionsLastlog = assay.eq (builtins.any (r: builtins.match "f /var/log/lastlog .*" r != null) tmpfiles) true;
    # `f` creates it if absent and leaves existing content alone -- `F` would truncate it on
    # every boot, destroying the login history this control exists to audit.
    createsWithoutTruncating = assay.eq (builtins.elemAt fields 0) "f";
    modeMatchesShadowLogin = assay.eq (builtins.elemAt fields 2) "0644";
    ownedByRoot = assay.eq (builtins.elemAt fields 3) "root";
  }
