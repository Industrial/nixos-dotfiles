# V-268170 (CAT II) — NixOS must enable the use of pwquality.
#
# The fix text replaces whole PAM files, three of them:
#
#   security.pam.services.passwd.text   = pkgs.lib.mkDefault (pkgs.lib.mkBefore "password requisite .../pam_pwquality.so");
#   security.pam.services.chpasswd.text = ...
#   security.pam.services.sudo.text     = ...
#
# `.text` is the ENTIRE PAM file, so each of those assignments reduces a complete stack to one
# line. The same defect as V-268081, and here it is worse: reducing `sudo`'s PAM file to a
# single `password` rule removes its `auth` stack, so sudo could not authenticate anyone at
# all. `mkBefore` does not help — it orders definitions of the same option, it does not
# prepend to a file.
#
# nixpkgs has structured PAM rules, so pam_pwquality can be added to the password stack
# without discarding the rest. `control = "requisite"` matches the fix text: a failed password
# quality check stops processing immediately.
#
# This is the control that makes the six pwquality.conf settings in base-safe actually
# enforce anything — on their own they are a config file with no consumer. It is kept out of
# base-safe because a wrong line in the password stack breaks `passwd` for everyone, and that
# needs VM proof first.
{pkgs, ...}: let
  pwqualityRule = {
    control = "requisite";
    modulePath = "${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so";
    order = 11000;
  };
in {
  security.pam.services = {
    passwd.rules.password.pwquality = pwqualityRule;
    chpasswd.rules.password.pwquality = pwqualityRule;
    sudo.rules.password.pwquality = pwqualityRule;
  };
}
