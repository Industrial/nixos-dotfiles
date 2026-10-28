# Colocated suite: V-268096 — kernel module load/unload audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268096.nix {};
in
  assay.suite "stig-V-268096" {
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
    ];
    coversBothArches = assay.eq (builtins.length mod.security.audit.rules) 2;
  }
