# V-268173 (CAT II) — NixOS must be configured to use AppArmor.
#
# Fix text: security.apparmor.enable = true;  (the fix text notes a reboot is required)
# Check: `systemctl status apparmor.service` must be enabled and active.
#
# Already satisfied by features/security/apparmor. Declared here so the control is provable
# from this module set; identical bool definitions merge without conflict.
{...}: {
  security.apparmor.enable = true;
}
