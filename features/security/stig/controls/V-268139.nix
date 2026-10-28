# V-268139 (CAT II) — NixOS must enable USBguard.
#
# Fix text enables the service and then says, in prose, to generate a policy by hand:
#
#   "use `usbguard list-devices` ... `usbguard allow-device` ... Note that the default
#    behavior is to block devices. When all connected USB devices have been permitted,
#    generate a ruleset by running `usbguard generate-policy` [and paste it into]
#    services.usbguard.rules"
#
# That default-block behaviour is the whole problem. Enabling usbguard with an EMPTY ruleset
# blocks every USB device that is not already authorised — including the keyboard you would
# need to authorise it with, and including the YubiKey that V-268136 and V-268177 depend on.
# A host-specific allow-list cannot be guessed, so this control enables the service and
# asserts the policy was supplied rather than shipping an empty one.
#
# `full` profile. The interaction with features/security/yubikey is recorded in
# docs/security/stig-triage.md.
{
  config,
  lib,
  ...
}: let
  hasRules = (config.services.usbguard.rules or null) != null && config.services.usbguard.rules != "";
in {
  assertions = [
    {
      assertion = hasRules;
      message = ''
        V-268139 enables usbguard, which BLOCKS every unauthorised USB device by default. With
        no ruleset that includes your keyboard and your YubiKey, so it must not be enabled
        with an empty policy.

        On the target host, authorise the devices you need and capture the policy:

          sudo usbguard list-devices
          sudo usbguard allow-device <id>      # for each device to permit
          sudo usbguard generate-policy

        then set services.usbguard.rules to the generated output, or exclude the control:

          security.stig.exclude."V-268139" = "<why this host cannot allow-list its USB devices>";
      '';
    }
  ];

  services.usbguard.enable = lib.mkIf hasRules true;
}
