# V-268171 (CAT II) — NixOS must enforce a delay of at least four seconds between logon
# prompts following a failed logon attempt.
#
# Fix text: security.loginDefs.settings."FAIL_DELAY" = "4";
#
# Four seconds after a failed console login. Mild by itself; it becomes noticeable only
# alongside V-268081's three-strikes lockout, which is in the full profile.
{...}: {
  security.loginDefs.settings.FAIL_DELAY = "4";
}
