# Colocated suite: V-268091 — audit records for privileged command usage.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268091.nix {};
in
  assay.suite "stig-V-268091" {
    ruleCount = assay.eq (builtins.length mod.security.audit.rules) 4;
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv"
      "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv"
    ];
    # Both architectures must be covered or a 32-bit binary evades the rule.
    coversBothArches = assay.eq (builtins.length (builtins.filter (r: builtins.match ".*arch=b32.*" r != null) mod.security.audit.rules)) 2;
  }
