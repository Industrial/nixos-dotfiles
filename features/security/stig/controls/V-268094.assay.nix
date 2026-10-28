# Colocated suite: V-268094 — mount syscall audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268094.nix {};
in
  assay.suite "stig-V-268094" {
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
      "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
    ];
    coversBothArches = assay.eq (builtins.length mod.security.audit.rules) 2;
  }
