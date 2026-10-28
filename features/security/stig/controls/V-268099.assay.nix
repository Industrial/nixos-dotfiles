# Colocated suite: V-268099 — ownership-change syscalls audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268099.nix {};
  rules = mod.security.audit.rules;
  syscallsIn = r: builtins.head (builtins.match ".*-S ([a-z,]+) .*" r);
in
  assay.suite "stig-V-268099" {
    rules = assay.eq rules [
      "-a always,exit -F arch=b32 -S lchown,fchown,chown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
      "-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
    ];
    coversBothArches = assay.eq (builtins.length rules) 2;

    # The published b32 and b64 lines order the syscalls differently. Assert the SET is the
    # same on both, so a transcription slip that drops one is caught.
    sameSyscallSetBothArches =
      assay.eq
      (builtins.sort (a: b: a < b) (builtins.filter builtins.isString (builtins.split "," (syscallsIn (builtins.head rules)))))
      (builtins.sort (a: b: a < b) (builtins.filter builtins.isString (builtins.split "," (syscallsIn (builtins.elemAt rules 1)))));
  }
