# Colocated suite: V-268100 — permission-change syscalls audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268100.nix {};
in
  assay.suite "stig-V-268100" {
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod"
      "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod"
    ];
    coversBothArches = assay.eq (builtins.length mod.security.audit.rules) 2;
  }
