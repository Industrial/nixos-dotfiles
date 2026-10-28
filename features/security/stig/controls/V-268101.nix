# V-268101 (CAT II) — NixOS must notify the SA and ISSO (at a minimum) when allocated audit
# record storage volume reaches 75 percent utilization.
#
# Fix text: space_left_action = syslog
#
# Worth correcting an earlier assumption in this baseline's own triage: this control was
# classified as needing "a real SA/ISSO mail destination", and it does not. The fix text asks
# for `syslog`, which routes the warning into the journal where the fleet's existing log
# pipeline can see it. There is no site-specific value to supply, so nothing here is blocked
# on an operator decision.
#
# The threshold itself is V-268103 (space_left = 25%); this control is only the action taken
# when that threshold is crossed. Same broken `environment.etc` pattern in the fix text as
# V-268103, routed through the auditd module's settings instead.
{...}: {
  security.auditd.settings.space_left_action = "syslog";
}
