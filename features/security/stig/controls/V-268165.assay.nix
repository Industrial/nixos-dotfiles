# Colocated suite: V-268165 — chage and chcon execution audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268165.nix {};
  rules = mod.security.audit.rules;
in
  assay.suite "stig-V-268165" {
    rules = assay.eq rules [
      "-a always,exit -F path=/run/current-system/sw/bin/chage -F perm=x -F auid>=1000 -F auid!=unset -k privileged-chage"
      "-a always,exit -F path=/run/current-system/sw/bin/chcon -F perm=x -F auid>=1000 -F auid!=unset -k perm_mod"
    ];
    ruleCount = assay.eq (builtins.length rules) 2;

    # chcon is an SELinux tool and will not be present on an AppArmor system. The rule is
    # kept verbatim and inert; this case records that the choice was deliberate.
    retainsSelinuxToolRule = assay.eq (builtins.length (builtins.filter (r: builtins.match ".*chcon.*" r != null) rules)) 1;

    allUseNixOSProfilePaths = assay.eq (builtins.all (r: builtins.match ".*/run/current-system/sw/bin/.*" r != null) rules) true;
  }
