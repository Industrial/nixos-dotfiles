# Colocated suite: V-268081 — three-strike lockout over a 15-minute window.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  mod = import ./V-268081.nix {lib = nixpkgsLib;};

  login = mod.security.pam.services.login;
  sshd = mod.security.pam.services.sshd;
in
  assay.suite "stig-V-268081" {
    # Both the console and SSH stacks, per the fix text.
    appliesToLogin = assay.eq login.logFailures true;
    appliesToSshd = assay.eq sshd.logFailures true;

    # The three numbers that are the requirement: 3 attempts, 900-second window.
    denyAfterThree = assay.eq login.rules.auth.faillock.settings.deny 3;
    windowIsFifteenMinutes = assay.eq login.rules.auth.faillock.settings.fail_interval 900;
    # unlock_time=0 means an administrator must clear the lock; there is no automatic
    # recovery. This is the reason the control is `full` and not base-safe.
    lockIsNotSelfClearing = assay.eq login.rules.auth.faillock.settings.unlock_time 0;
    auditsFailures = assay.eq login.rules.auth.faillock.settings.audit true;

    sameSettingsOnBothStacks = assay.eq sshd.rules.auth.faillock.settings login.rules.auth.faillock.settings;

    # Structured rules, NOT the whole-file `.text` replacement the fix text demands. That
    # replacement omits the session and password stacks and would strip pam_limits, disabling
    # V-268085 in the same benchmark.
    doesNotReplaceTheWholePamFile = assay.eq (login ? text) false;

    # And the assertion that says so is present and explains it.
    carriesTheWarningAssertion = assay.eq (builtins.length mod.assertions) 1;
    warningNamesTheBrokenControl =
      assay.eq (builtins.match ".*V-268085.*" (builtins.head mod.assertions).message != null) true;
  }
