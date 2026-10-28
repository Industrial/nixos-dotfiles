# V-268172 (CAT I) — NixOS must not allow an unattended or automatic logon to the system via
# the console.
#
# Fix text: services.xserver.displayManager.autologon.user = null;
#
# That attribute path does not exist. There is no `autologon` option in nixpkgs — the option
# is `services.displayManager.autoLogin` (camel-case `Login`, and no longer under
# `xserver`). Applying the fix text literally is an "option does not exist" error, or on a
# freeform submodule would create a dead attribute while autologin stayed on.
#
# Setting it to `null` is also not how the option works: autoLogin is disabled by leaving
# `enable` false, which is the nixpkgs default.
#
# So this control asserts the absence of console autologin rather than setting a value. There
# is nothing to configure when the secure state is the default; what matters is that a host
# does not turn it on, and an assertion is the only way to express that in a module.
#
# `full` profile, CAT I. On this fleet the greeter is Hyprland's, so the check's GDM-centric
# reading is noted for the report's justification column.
{
  config,
  lib,
  ...
}: let
  autoLogin = config.services.displayManager.autoLogin or {};
  enabled = autoLogin.enable or false;
in {
  assertions = [
    {
      assertion = !enabled;
      message = ''
        V-268172 (CAT I): console autologin is enabled
        (services.displayManager.autoLogin.enable = true${
          lib.optionalString (autoLogin.user or null != null) ", user = ${toString autoLogin.user}"
        }).
        An unattended logon defeats every authentication control in this baseline. Disable it,
        or exclude the control with a written justification.

        Note the published fix text names services.xserver.displayManager.autologon.user,
        which is not a real option — the option is services.displayManager.autoLogin.
      '';
    }
  ];
}
