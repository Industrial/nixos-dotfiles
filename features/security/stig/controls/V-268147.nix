# V-268147 (CAT II) — NixOS must protect wireless access to the system using authentication of
# users and/or devices.
#
# Fix text: hardware.bluetooth.enable = false;
#
# Note the mismatch between requirement and fix: the requirement is about authenticating
# wireless access, and the fix disables Bluetooth. Bluetooth is the "wireless access" being
# addressed, and disabling it is how the STIG chooses to satisfy "authentication of devices".
#
# This DOES change behaviour on this fleet, unlike its sibling V-268146: Bluetooth is enabled
# by features/nixos/bluetooth, which profiles/base.nix imports. Applying this control removes
# Bluetooth audio and every Bluetooth peripheral — the conflict recorded in
# docs/security/stig-triage.md.
#
# `full` profile.
{...}: {
  hardware.bluetooth.enable = false;
}
