# V-268151 (CAT II) — NixOS must have time synchronization enabled.
#
# Fix text: services.timesyncd.enable = true;
# Check greps /etc/nixos for `services.timesyncd.enable = true`.
#
# Already set by features/nixos/systemd/default.nix; declared here so the control is provable
# from this module set. Identical bool definitions merge without conflict.
#
# The check reads configuration *source* in /etc/nixos, which a flake-deployed host does not
# keep there. The VM test asserts the unit is actually enabled, which is the stronger claim;
# the discrepancy belongs in the report's justification column.
{...}: {
  services.timesyncd.enable = true;
}
