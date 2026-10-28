# Colocated suite: V-268163 — xattr modification audited for users and for root.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268163.nix {};
  rules = mod.security.audit.rules;
  countMatching = pat: builtins.length (builtins.filter (r: builtins.match pat r != null) rules);
in
  assay.suite "stig-V-268163" {
    ruleCount = assay.eq (builtins.length rules) 4;

    coversB32 = assay.eq (countMatching ".*arch=b32.*") 2;
    coversB64 = assay.eq (countMatching ".*arch=b64.*") 2;

    # The root-side rules are the easy ones to lose in transcription, and losing them means a
    # root-performed xattr change is never recorded.
    coversUnprivilegedUsers = assay.eq (countMatching ".*auid>=1000.*") 2;
    coversRoot = assay.eq (countMatching ".*auid=0.*") 2;

    allSixSyscalls = assay.eq (countMatching ".*setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr.*") 4;
  }
