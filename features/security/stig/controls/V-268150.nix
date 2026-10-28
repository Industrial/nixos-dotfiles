# V-268150 (CAT II) — NixOS must synchronize internal information system clocks to the
# authoritative time source when the time difference is greater than one second.
#
# Fix text: services.timesyncd.extraConfig = "PollIntervalMaxSec=60";
#
# That option has been REMOVED from nixpkgs, not merely renamed — evaluating it fails with
# "can no longer be used since it's been removed. Use services.timesyncd.settings.Time
# instead." So the published fix text does not just warn, it breaks the build. Declared
# through the structured settings attrset instead.
#
# Check: "If PollIntervalMaxSec is greater than 60, is commented out, or is missing, this is a
# finding." An inequality, so 60 is a ceiling and a smaller value would also pass — unlike
# V-268160, where the check is an equality test and tightening is non-compliant.
#
# The check greps /etc/nixos/, which a flake-deployed host does not populate; the VM test
# asserts the rendered timesyncd config instead. Noted for the report's justification column.
#
# Paired with V-268151 (timesyncd enabled). V-268149, which pins the servers themselves to DoD
# hosts, is in the full profile because those hosts are unreachable from here.
{...}: {
  services.timesyncd.settings.Time.PollIntervalMaxSec = 60;
}
