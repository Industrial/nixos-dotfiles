# V-268085 (CAT III) — NixOS must be configured to limit the number of concurrent sessions to
# 10 for all accounts and/or account types.
#
# The only CAT III control in the whole STIG.
#
# `security.pam.loginLimits` is a list, and this repo already contributes `@pipewire` rtprio,
# nice and memlock entries to it, so this appends rather than replaces — confirmed by the
# control's check text, which shows exactly that mixed limits.conf.
{...}: {
  security.pam.loginLimits = [
    {
      domain = "*";
      item = "maxlogins";
      type = "hard";
      value = "10";
    }
  ];
}
