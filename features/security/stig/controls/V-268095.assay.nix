# Colocated suite: V-268095 — file deletion syscalls audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268095.nix {};
in
  assay.suite "stig-V-268095" {
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F arch=b32 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"
      "-a always,exit -F arch=b64 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"
    ];
    coversBothArches = assay.eq (builtins.length mod.security.audit.rules) 2;
    # All five syscalls named by the requirement appear in each rule.
    namesAllFiveSyscalls = assay.eq (builtins.all (r: builtins.match ".*rename,unlink,rmdir,renameat,unlinkat.*" r != null) mod.security.audit.rules) true;
  }
