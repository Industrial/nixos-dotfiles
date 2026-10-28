# V-268102 (CAT II) — NixOS must notify the SA and ISSO (at a minimum) when allocated audit
# record storage volume reaches 90 percent utilization.
#
# Fix text: admin_space_left_action = syslog
#
# Same shape as V-268101, at the more urgent threshold (V-268104 sets admin_space_left = 10%).
# Also needs no site-specific value, contrary to this baseline's earlier triage note.
{...}: {
  security.auditd.settings.admin_space_left_action = "syslog";
}
