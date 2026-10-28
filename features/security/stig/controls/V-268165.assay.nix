# Colocated suite: V-268165 — chage execution audited; chcon deliberately not watched.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268165.nix {};
  rules = mod.security.audit.rules;
in
  assay.suite "stig-V-268165" {
    rules = assay.eq rules [
      "-a always,exit -F path=/run/current-system/sw/bin/chage -F perm=x -F auid>=1000 -F auid!=unset -k privileged-chage"
    ];
    ruleCount = assay.eq (builtins.length rules) 1;

    watchesChage = assay.eq (builtins.match ".*chage.*" (builtins.head rules) != null) true;

    # The chcon rule from the fix text is deliberately absent. auditctl fails the WHOLE rules
    # file on a watch whose path does not exist, and chcon is an SELinux tool that cannot
    # exist on this AppArmor system (V-268173). Keeping it would mean no audit rules at all.
    # This case is the guard against someone "restoring" it from the published text.
    doesNotWatchChcon = assay.eq (builtins.any (r: builtins.match ".*chcon.*" r != null) rules) false;

    usesNixOSProfilePath = assay.eq (builtins.match ".*/run/current-system/sw/bin/.*" (builtins.head rules) != null) true;
  }
