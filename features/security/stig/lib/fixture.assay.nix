# Colocated suite: the shared NixOS fixture evaluates and its helpers behave.
#
# The fixture underpins every consequence-checking control suite, so a silent change here
# would weaken many assertions at once.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./fixture.nix;

  bare = fixture.evalWith [];
  withAudit = fixture.evalWith [./../controls/V-268080.nix];
in
  assay.suite "stig-fixture" {
    # Evaluates at all, and is a real NixOS system.
    evaluates = assay.eq (builtins.isAttrs bare) true;
    hasStateVersion = assay.eq bare.system.stateVersion "25.05";

    # The fixture must not itself enable the things controls are asserting, or every
    # consequence check would pass for the wrong reason.
    bareHasNoAudit = assay.eq bare.security.audit.enable false;
    bareHasNoAuditKernelParam = assay.eq (builtins.elem "audit=1" bare.boot.kernelParams) false;

    # ...and must faithfully reflect a control that is applied.
    auditModuleTakesEffect = assay.eq (builtins.elem "audit=1" withAudit.boot.kernelParams) true;

    etcMatchingFindsAuditEntries = assay.eq (builtins.length (builtins.attrNames (fixture.etcMatching withAudit "audit/.*")) > 0) true;
    etcMatchingFindsNothingBogus = assay.eq (fixture.etcMatching withAudit "no-such-prefix/.*") {};

    tmpfilesFieldsSplitsALine = assay.eq (fixture.tmpfilesFields "d /var/log/audit 0700 root root -") [
      "d"
      "/var/log/audit"
      "0700"
      "root"
      "root"
      "-"
    ];
    tmpfilesFieldsCollapsesRuns = assay.eq (fixture.tmpfilesFields "z  /tmp   0600 root root -") [
      "z"
      "/tmp"
      "0600"
      "root"
      "root"
      "-"
    ];
  }
