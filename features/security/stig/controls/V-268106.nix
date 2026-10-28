# V-268106 (CAT II) — The NixOS audit system must take appropriate action when an audit
# processing failure occurs.
#
# Same situation as V-268105: the fix text says HALT, the check accepts "SYSLOG", "SINGLE", or
# "HALT". SYSLOG is compliant and does not power the machine off on a transient audit write
# error, which is the more likely trigger of the two.
{...}: {
  security.auditd.settings.disk_error_action = "SYSLOG";
}
