# V-268141 (CAT II) — NixOS must manage excess capacity, bandwidth, or other redundancy to
# limit the effects of information flooding denial-of-service attacks.
#
# Fix text asks for exactly one thing despite the broad title: IPv4 TCP syncookies.
# Check: `sysctl net.ipv4.tcp_syncookies` must return 1, otherwise a finding.
#
# The requirement title and the check do not describe the same scope. We satisfy the check,
# because that is what an assessor runs. Recorded in the report's justification column.
{...}: {
  boot.kernel.sysctl."net.ipv4.tcp_syncookies" = 1;
}
