# V-268081 (CAT II) — NixOS must enforce the limit of three consecutive invalid logon
# attempts by a user during a 15-minute time period.
#
# The published fix text replaces the ENTIRE PAM file for login and sshd:
#
#   security.pam.services = let pamfile = ''
#     auth required pam_faillock.so preauth silent audit deny=3 fail_interval=900 unlock_time=0
#     auth sufficient pam_unix.so nullok try_first_pass
#     auth [default=die] pam_faillock.so authfail audit deny=3 fail_interval=900 unlock_time=0
#     auth sufficient pam_faillock.so authsucc
#
#     account required pam_faillock.so
#   '';
#   in { login.text = ...; sshd.text = ...; };
#
#   "Note that the entire pam file must be entered as this pamfile string."
#
# That note is the problem. `security.pam.services.<n>.text` IS the whole file, and the
# replacement contains only `auth` and `account` lines — no `session` stack and no `password`
# stack. Applying it literally would strip pam_systemd, pam_env, pam_limits and pam_unix's
# session handling from login, which among other things BREAKS V-268085: maxlogins is enforced
# by pam_limits, and pam_limits would no longer be in the file. One control's fix text
# silently disables another control in the same benchmark.
#
# So the same stack is built from nixpkgs' structured PAM rules, around the rules nixpkgs
# already renders. pam_faillock does nothing useful as a single line: it has to be called
# three times, and each call says where in the stack it stands (pam_faillock(8), second
# example, which is the one for a `sufficient` pam_unix):
#
#   auth    required      pam_faillock.so preauth ...   before anything asks for a password:
#                                                       refuses a locked account
#   auth    sufficient    pam_unix.so ...               nixpkgs' own rule, untouched
#   auth    [default=die] pam_faillock.so authfail ...  reached only when pam_unix failed:
#                                                       records the failure and ends the stack
#   account required      pam_faillock.so               after a successful authentication:
#                                                       clears the tally, which is what makes
#                                                       the three attempts "consecutive"
#
# An earlier version of this module set `logFailures` and the rule's settings only. nixpkgs
# renders that as one `auth required pam_faillock.so` line with no preauth/authfail argument,
# which checks the tally and never writes it: no account was ever locked (GH-349, ADR-0008).
#
# Three deliberate differences from the fix text:
#
#   - No `authsucc` line. Behind a `sufficient` pam_unix it cannot be reached: a correct
#     password ends the stack before it, and a wrong one ends it at authfail. The account
#     line does the reset instead, as the man page prescribes for this layout.
#   - No `even_deny_root` and no `dir=`, which appear in the check text's sample line but not
#     in the fix text. The check's finding condition is fail_interval on the preauth line.
#     Root is therefore never locked, and the tally lives in /run/faillock, which a reboot
#     clears. Both are kept as ways back in to a machine whose lock never expires.
#   - The preauth line is `silent`, as in the fix text: a locked account is not announced, so
#     the prompt does not tell an attacker which accounts exist.
#
# unlock_time=0 means a locked account stays locked until an administrator clears it:
#
#   faillock --user <name> --reset
#
# SSH with a public key is NOT blocked by a locked tally, and does not clear it. sshd does
# not run the auth stack for a key login, so preauth never sees it; and since linux-pam 1.7
# the account line skips its reset when the auth stack has not run in the same transaction.
# The requirement counts invalid logon attempts, and a key login is not one. This is also the
# operator's way back in: log in with the key, then run the reset above through sudo. The VM
# test for this control proves both halves on a booted machine.
#
# What passes through these stacks: `login` is the console, and GDM's `gdm-password` service
# (`auth substack login`, `account include login`), so the graphical greeter and the lock
# screen count toward the same tally. `sshd` only authenticates through PAM where password
# or keyboard-interactive authentication is on.
#
# `[default=die]` ends the stack on any pam_unix failure, so a `sufficient` module that
# nixpkgs orders after pam_unix (LDAP, SSSD, Kanidm, OTPW) would no longer be consulted. The
# fix text has the same property. No host in this fleet uses one.
{
  lib,
  config,
  ...
}: let
  faillockSo = "${config.security.pam.package}/lib/security/pam_faillock.so";

  policy = {
    deny = 3;
    fail_interval = 900;
    unlock_time = 0;
    audit = true;
  };

  services = ["login" "sshd"];

  rulesOf = service: config.security.pam.services.${service}.rules;

  lockout = service: {
    # Switches on nixpkgs' own `faillock` auth rule: `required`, and ordered ahead of every
    # module that asks for a password. Given the preauth argument it becomes the first of
    # the three calls.
    logFailures = true;

    rules = {
      auth = {
        faillock = {
          # mkBefore: the position keyword leads the line, as in the check text.
          args = lib.mkBefore ["preauth"];
          settings = policy // {silent = true;};
        };

        # Relative to pam_unix, never a constant: nixpkgs renumbers its rules between
        # releases, and a constant could end up in front of pam_unix, where every logon
        # would be recorded as a failure.
        faillock-authfail = {
          order = (rulesOf service).auth.unix.order + 10;
          control = "[default=die]";
          modulePath = faillockSo;
          args = lib.mkBefore ["authfail"];
          settings = policy;
        };
      };

      account.faillock = {
        order = (rulesOf service).account.unix.order - 10;
        control = "required";
        modulePath = faillockSo;
      };
    };
  };

  # The first rule that asks for a password. nixpkgs adds `unix-early` only when a module
  # needs the password before pam_unix proper (gnome-keyring, on a desktop).
  firstPasswordOrder = service: let
    inherit ((rulesOf service)) auth;
  in
    if auth ? unix-early
    then lib.min auth.unix-early.order auth.unix.order
    else auth.unix.order;
in {
  security.pam.services = lib.genAttrs services lockout;

  assertions =
    map (service: {
      assertion = (rulesOf service).auth.faillock.order < firstPasswordOrder service;
      message = ''
        V-268081: in the ${service} PAM service, the pam_faillock preauth rule is not ordered
        before pam_unix. A locked account would be asked for its password and could log in.
        nixpkgs has reordered its auth rules; fix the order in controls/V-268081.nix.
      '';
    })
    services;
}
