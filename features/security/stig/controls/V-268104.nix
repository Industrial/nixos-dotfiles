# V-268104 (CAT II) — NixOS must take action when allocated audit record storage volume
# reaches 90 percent of the repository maximum audit record storage capacity.
#
# Same broken fix-text pattern as V-268103; declared through the auditd module's settings.
#
# `admin_space_left = 10%` is the 90-percent threshold expressed as remaining space. auditd
# treats admin_space_left as the more urgent of the two thresholds.
{...}: {
  security.auditd.settings.admin_space_left = "10%";
}
