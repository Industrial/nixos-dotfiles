# Colocated suite: V-268148 — satisfied by V-268080 + V-268091, verified rather than asserted.
#
# V-268148's fix text duplicates V-268091's four rules exactly. This control therefore emits
# nothing, and the suite's job is to prove the coverage claim still holds against the real
# V-268091 and V-268080 modules — so the claim cannot rot silently.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268148.nix {};
  rulesProvider = import ./V-268091.nix {};
  daemonProvider = import ./V-268080.nix {};

  # Verbatim from V-268148's own fix text.
  required = [
    "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
    "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
    "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv"
    "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv"
  ];

  provided = rulesProvider.security.audit.rules;
in
  assay.suite "stig-V-268148" {
    # This control contributes no configuration of its own, on purpose.
    emitsNothing = assay.eq self {};

    # Every rule V-268148 requires is supplied by V-268091.
    everyRequiredRuleIsProvided = assay.eq (builtins.all (r: builtins.elem r provided) required) true;
    # ...and V-268091 supplies nothing beyond them, so the two controls stay in lockstep.
    providerAddsNothingExtra = assay.eq (builtins.all (r: builtins.elem r required) provided) true;

    # The daemon half of V-268148's fix text.
    auditdEnabled = assay.eq daemonProvider.security.auditd.enable true;
    auditEnabled = assay.eq daemonProvider.security.audit.enable true;
  }
