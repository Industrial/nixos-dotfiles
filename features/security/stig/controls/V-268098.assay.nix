# Colocated suite: V-268098 — denied file-access syscalls audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268098.nix {};
  rules = mod.security.audit.rules;
  countMatching = pat: builtins.length (builtins.filter (r: builtins.match pat r != null) rules);
in
  assay.suite "stig-V-268098" {
    ruleCount = assay.eq (builtins.length rules) 4;

    # Two architectures x two denial outcomes.
    coversB32 = assay.eq (countMatching ".*arch=b32.*") 2;
    coversB64 = assay.eq (countMatching ".*arch=b64.*") 2;
    coversEacces = assay.eq (countMatching ".*exit=-EACCES.*") 2;
    coversEperm = assay.eq (countMatching ".*exit=-EPERM.*") 2;

    # Only denials are audited; an unconditional rule here would flood the log.
    everyRuleFiltersOnDenial = assay.eq (builtins.all (r: builtins.match ".*exit=-E(ACCES|PERM).*" r != null) rules) true;

    # The fix text uses `-F key=access`, not `-k`. Kept verbatim.
    usesKeyFieldForm = assay.eq (countMatching ".*-F key=access$") 4;
  }
