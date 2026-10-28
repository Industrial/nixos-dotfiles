# Colocated suite: V-268166 — lastlog watched for logon records.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268166.nix {};
in
  assay.suite "stig-V-268166" {
    rules = assay.eq mod.security.audit.rules ["-w /var/log/lastlog -p wa -k logins"];
    isWriteAttrWatch = assay.eq (builtins.match "-w .* -p wa -k logins" (builtins.head mod.security.audit.rules) != null) true;
  }
