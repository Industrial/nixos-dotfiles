# Colocated suite: V-268170 — pam_pwquality in the password stack.
#
# This suite proves what the module DECLARES. That `passwd` then refuses a weak password is
# proven on a booted machine by tests/vm/pam.nix: the first version of this module passed a
# suite of this kind while refusing nothing.
let
  assay = import ./../../../../common/assay/default.nix;

  # pam_unix's order differs per service here on purpose: the rule must follow each
  # service's own pam_unix, not a number that happens to fit one of them.
  unixOrders = {
    passwd = 10200;
    chpasswd = 10300;
    sudo = 12000;
  };
  mod = import ./V-268170.nix {
    pkgs.libpwquality.lib = "/nix/store/fake-libpwquality";
    config.security.pam.services = builtins.mapAttrs (_: order: {rules.password.unix.order = order;}) unixOrders;
  };
  inherit (mod.security.pam) services;
  checked = ["passwd" "chpasswd" "sudo"];
  rule = service: services.${service}.rules.password.pwquality;
in
  assay.suite "stig-V-268170" {
    # All three services the check greps for, and no other.
    coversExactlyTheCheckedServices = assay.eq (builtins.attrNames services) ["chpasswd" "passwd" "sudo"];

    # In the PASSWORD stack, not auth — pam_pwquality checks a new password's quality.
    isInThePasswordStackOnly = assay.eq (map (s: builtins.attrNames services.${s}.rules) checked) [["password"] ["password"] ["password"]];

    # `requisite`, per the fix text: a failed quality check stops processing immediately
    # rather than letting a later module succeed.
    isRequisite = assay.eq (map (s: (rule s).control) checked) ["requisite" "requisite" "requisite"];
    pointsAtPamPwquality = assay.eq (rule "passwd").modulePath "/nix/store/fake-libpwquality/lib/security/pam_pwquality.so";

    # BEFORE pam_unix. nixpkgs' pam_unix is `sufficient`: a rule behind it is never consulted
    # once pam_unix has taken the password. That was the defect (order 11000 against 10200).
    precedesEachServicesOwnPamUnix = assay.eq (map (s: (rule s).order) checked) [10190 10290 11990];
    neverBehindPamUnix = assay.eq (builtins.all (s: (rule s).order < unixOrders.${s}) checked) true;

    # pam_unix stores the password pam_pwquality checked, and does not ask for its own.
    pamUnixUsesTheCheckedPassword =
      assay.eq (map (s: services.${s}.rules.password.unix.settings.use_authtok) checked) [true true true];
    # Only that one setting of nixpkgs' pam_unix rule is touched.
    leavesTheRestOfPamUnixAlone = assay.eq services.passwd.rules.password.unix {settings.use_authtok = true;};

    # The policy comes from pwquality.conf; arguments here would shadow it.
    passesNoModuleArguments = assay.eq [((rule "passwd") ? args) ((rule "passwd") ? settings)] [false false];

    # Structured rules, NOT the whole-file `.text` replacement the fix text demands. For sudo
    # that replacement would have removed the auth stack entirely, so sudo could not
    # authenticate anyone.
    doesNotReplaceAnyPamFile = assay.eq (builtins.any (s: services.${s} ? text) checked) false;
  }
