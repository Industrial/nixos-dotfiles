# Colocated suite: V-268081 — three-strike lockout over a 15-minute window.
#
# This suite proves what the module DECLARES. That the declared stack locks an account is
# proven on a booted machine by tests/vm/pam.nix: the first version of this module passed a
# suite of this kind while locking nobody.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  # The rule orders the module reads from the evaluated system. `unixEarly` is the rule
  # nixpkgs adds on a desktop, where gnome-keyring needs the password before pam_unix.
  configWith = {
    faillockOrder ? 10400,
    unixEarly ? null,
  }: {
    security.pam = {
      package = "/nix/store/fake-linux-pam";
      services = nixpkgsLib.genAttrs ["login" "sshd"] (_: {
        rules = {
          auth =
            {
              faillock.order = faillockOrder;
              unix.order = 13100;
            }
            // nixpkgsLib.optionalAttrs (unixEarly != null) {unix-early.order = unixEarly;};
          account.unix.order = 11000;
        };
      });
    };
  };

  modWith = args:
    import ./V-268081.nix {
      lib = nixpkgsLib;
      config = configWith args;
    };
  mod = modWith {};

  inherit (mod.security.pam.services) login sshd;
  preauth = login.rules.auth.faillock;
  authfail = login.rules.auth.faillock-authfail;
  account = login.rules.account.faillock;

  holds = m: map (a: a.assertion) m.assertions;
in
  assay.suite "stig-V-268081" {
    # Both the console and SSH stacks, per the fix text, and the same rules in each.
    appliesToLoginAndSshdOnly = assay.eq (builtins.attrNames mod.security.pam.services) ["login" "sshd"];
    sameRulesOnBothStacks = assay.eq (builtins.toJSON sshd.rules.auth.faillock.settings) (builtins.toJSON preauth.settings);

    # --- call 1: preauth, on nixpkgs' own rule ---
    enablesTheBuiltInRule = assay.eq login.logFailures true;
    # mkBefore (priority 500), so the keyword leads the rendered arguments.
    preauthKeywordLeads = assay.eq [(preauth.args._type or null) preauth.args.priority preauth.args.content] ["order" 500 ["preauth"]];
    # The three numbers that are the requirement: 3 attempts, 900-second window, and
    # unlock_time=0 — an administrator must clear the lock.
    preauthCarriesThePolicy = assay.eq preauth.settings {
      deny = 3;
      fail_interval = 900;
      unlock_time = 0;
      audit = true;
      silent = true;
    };
    # The check's finding condition, on the preauth line: set, 900 or less, and not 0.
    failIntervalIsWithinTheCheck = assay.eq (preauth.settings.fail_interval > 0 && preauth.settings.fail_interval <= 900) true;

    # --- call 2: authfail, directly behind pam_unix ---
    # Without this call no failure is ever recorded. Its absence was the defect.
    recordsFailures = assay.eq authfail.args.content ["authfail"];
    authfailEndsTheStack = assay.eq authfail.control "[default=die]";
    authfailFollowsPamUnix = assay.eq authfail.order 13110;
    authfailCarriesTheSamePolicy = assay.eq authfail.settings {
      deny = 3;
      fail_interval = 900;
      unlock_time = 0;
      audit = true;
    };
    authfailIsPamFaillock = assay.eq authfail.modulePath "/nix/store/fake-linux-pam/lib/security/pam_faillock.so";

    # --- call 3: the account line, which clears the tally after a successful logon ---
    accountLineIsRequired = assay.eq [account.control account.modulePath] ["required" "/nix/store/fake-linux-pam/lib/security/pam_faillock.so"];
    accountLinePrecedesPamUnix = assay.eq account.order 10990;

    # No authsucc rule: behind a `sufficient` pam_unix it would be unreachable.
    declaresNoUnreachableAuthsuccRule = assay.eq (builtins.attrNames login.rules.auth) ["faillock" "faillock-authfail"];
    # Not in the fix text; root and a reboot stay as ways back in.
    doesNotLockRootOrPersistTheTally = assay.eq [(preauth.settings ? even_deny_root) (preauth.settings ? dir)] [false false];

    # Structured rules, NOT the whole-file `.text` replacement the fix text demands. That
    # replacement omits the session and password stacks and would strip pam_limits, disabling
    # V-268085 in the same benchmark.
    doesNotReplaceTheWholePamFile = assay.eq [(login ? text) (sshd ? text)] [false false];

    # --- the ordering assertion: preauth must come before anything asks for a password ---
    oneAssertionPerService = assay.eq (builtins.length mod.assertions) 2;
    holdsOnTheNixpkgsOrder = assay.eq (holds mod) [true true];
    holdsWithAnEarlyPamUnix = assay.eq (holds (modWith {unixEarly = 11700;})) [true true];
    refusesPreauthBehindPamUnix = assay.eq (holds (modWith {faillockOrder = 13200;})) [false false];
    refusesPreauthBehindTheEarlyPamUnix = assay.eq (holds (modWith {
      faillockOrder = 12000;
      unixEarly = 11700;
    })) [false false];
    assertionNamesTheConsequence =
      assay.eq (builtins.match ".*locked account.*could log in.*" (builtins.head mod.assertions).message != null) true;
  }
