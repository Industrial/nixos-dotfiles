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
# nixpkgs has structured PAM rules, so pam_pwquality is added to the password stack without
# discarding the rest. Two things make it enforce, and both are needed:
#
#   password requisite  pam_pwquality.so            first: asks for the new password and
#                                                   checks it against pwquality.conf
#   password sufficient pam_unix.so ... use_authtok then: stores THAT password, and does not
#                                                   ask for one of its own
#
#   - Order. nixpkgs' pam_unix rule is `sufficient`, so anything placed after it is never
#     consulted once pam_unix has accepted the password. An earlier version of this module
#     put pam_pwquality there, at a constant order, and it enforced nothing (GH-349,
#     ADR-0008). The order is now relative to pam_unix's own.
#   - use_authtok. Without it pam_unix may prompt again and store a password that
#     pam_pwquality never saw.
#
# `requisite` matches the fix text: a failed quality check ends the stack at once.
#
# The module takes no arguments. The policy (minlen, the four credit settings, difok,
# dictcheck) is read from /etc/security/pwquality.conf, which V-268126, V-268127, V-268128,
# V-268129, V-268134, V-268145 and V-268169 write. This control is what makes those settings
# enforce anything: on their own they are a config file with no consumer.
#
# Scope, as the check names it: passwd, chpasswd and sudo. Two limits follow from the
# benchmark, not from this module:
#
#   - root is warned, not refused. pam_pwquality enforces for root only with
#     `enforce_for_root`, which no control sets. `passwd <user>` as root, and chpasswd (which
#     only root runs), print "BAD PASSWORD" and set the password anyway. The VM test pins it.
#   - a password that has expired is changed in the password stack of the service being
#     logged in to (`login`, and GDM through it), which the check does not name and this
#     control does not touch.
{
  pkgs,
  config,
  ...
}: let
  services = ["passwd" "chpasswd" "sudo"];

  quality = service: {
    rules.password = {
      pwquality = {
        control = "requisite";
        modulePath = "${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so";
        # Relative to pam_unix, never a constant: see "Order" above.
        order = config.security.pam.services.${service}.rules.password.unix.order - 10;
      };
      unix.settings.use_authtok = true;
    };
  };
in {
  security.pam.services = builtins.listToAttrs (map (service: {
      name = service;
      value = quality service;
    })
    services);
}
