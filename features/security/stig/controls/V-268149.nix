# V-268149 (CAT II) — NixOS must compare internal clocks at least every 24 hours with a
# server synchronized to a USNO time server, a DoW network time server, or GPS.
#
# Fix text pins:
#
#   networking.timeServers = [ "tick.usnogps.navy.mil" "tock.usnogps.navy.mil" ];
#
# Those hosts are on DoD networks and are not reachable from a home connection. Applying this
# control replaces the working NTP pool with two unreachable names, so the host stops
# synchronising its clock — breaking time sync in the name of securing it, and taking
# V-268150's poll interval and the audit timestamps with it.
#
# Transcribed as published anyway, because this control is in the `full` profile and the
# profile's purpose is to represent the benchmark faithfully on a target where the
# infrastructure exists. The generic requirement — compare clocks at least every 24 hours
# against an authoritative source — is already met on this fleet by V-268150 and V-268151
# against the nixpkgs NTP pool; only the specific server list is inapplicable.
#
# For a host outside a DoD network the honest action is an exclusion citing V-268150 and
# V-268151, which is how docs/security/stig-triage.md classifies it.
{...}: {
  networking.timeServers = [
    "tick.usnogps.navy.mil"
    "tock.usnogps.navy.mil"
  ];
}
