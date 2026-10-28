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
# nixpkgs has structured PAM rules (security/pam.nix declares a `faillock` rule), so the
# requirement can be expressed without discarding the rest of the stack:
#
#   - `logFailures` enables the pam_faillock rule in the service's auth stack;
#   - `rules.auth.faillock.settings` carries deny / fail_interval / unlock_time.
#
# unlock_time=0 means a locked account stays locked until an administrator clears it
# (`faillock --reset`). That is what the fix text specifies, and it is why this control is in
# the `full` profile and not base-safe: three mistyped passwords lock you out of your own
# machine with no automatic recovery.
{lib, ...}: let
  faillockSettings = {
    deny = 3;
    fail_interval = 900;
    unlock_time = 0;
    audit = true;
  };
in {
  security.pam.services = {
    login = {
      logFailures = true;
      rules.auth.faillock.settings = faillockSettings;
    };
    sshd = {
      logFailures = true;
      rules.auth.faillock.settings = faillockSettings;
    };
  };

  assertions = [
    {
      assertion = !(lib.hasAttrByPath ["security" "pam" "services" "login" "text"] {});
      message = ''
        V-268081: do not set security.pam.services.<name>.text to the pamfile from this
        control's fix text. That option is the ENTIRE PAM file, and the published string
        contains no session or password stack — applying it strips pam_limits and so disables
        V-268085 (maxlogins) along with session setup. Use the structured rules instead.
      '';
    }
  ];
}
