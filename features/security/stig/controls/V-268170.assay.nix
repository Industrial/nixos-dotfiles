# Colocated suite: V-268170 — pam_pwquality in the password stack.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268170.nix {
    pkgs.libpwquality.lib = "/nix/store/fake-libpwquality";
  };
  services = mod.security.pam.services;
in
  assay.suite "stig-V-268170" {
    # All three services the check greps for.
    coversPasswd = assay.eq (services.passwd.rules.password ? pwquality) true;
    coversChpasswd = assay.eq (services.chpasswd.rules.password ? pwquality) true;
    coversSudo = assay.eq (services.sudo.rules.password ? pwquality) true;

    # In the PASSWORD stack, not auth — pam_pwquality checks a new password's quality.
    isInThePasswordStack = assay.eq (services.passwd.rules ? auth) false;

    # `requisite`, per the fix text: a failed quality check stops processing immediately
    # rather than letting a later module succeed.
    isRequisite = assay.eq services.passwd.rules.password.pwquality.control "requisite";
    pointsAtPamPwquality =
      assay.eq (builtins.match ".*pam_pwquality\\.so" services.passwd.rules.password.pwquality.modulePath != null) true;

    # Structured rules, NOT the whole-file `.text` replacement the fix text demands. For sudo
    # that replacement would have removed the auth stack entirely, so sudo could not
    # authenticate anyone.
    doesNotReplaceAnyPamFile =
      assay.eq (builtins.any (s: s ? text) [services.passwd services.chpasswd services.sudo]) false;

    sameRuleEverywhere =
      assay.eq (services.chpasswd.rules.password.pwquality == services.passwd.rules.password.pwquality) true;
  }
