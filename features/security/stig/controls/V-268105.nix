# V-268105 (CAT II) — The NixOS audit system must take appropriate action when the audit
# storage volume is full.
#
# The fix text's value is `disk_full_action = HALT`, which powers the machine off the moment
# the audit volume fills. On a workstation that is an unplanned shutdown in the middle of
# whatever you were doing.
#
# The CHECK text is broader than the fix text and settles it:
#
#   If the value of the "disk_full_action" option is not "SYSLOG", "SINGLE", or "HALT", [...]
#   this is a finding.
#
# SYSLOG is therefore fully compliant and does not halt the host, so that is what is used. This
# is a case where reading the check rather than copying the fix turns a disruptive control into
# a harmless one — the same reasoning that keeps the control in the host-wide profile at all.
#
# The full profile may prefer HALT, where availability is subordinate to audit integrity.
{...}: {
  security.auditd.settings.disk_full_action = "SYSLOG";
}
