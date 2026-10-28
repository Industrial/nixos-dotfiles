# V-268166 (CAT II) — NixOS must generate audit records when concurrent logons to the same
# account occur from different sources.
#
# Fix text: -w /var/log/lastlog -p wa -k logins
#
# /var/log/lastlog does not exist until something writes a login record, and auditctl fails
# the ENTIRE rules file on a watch whose path is missing (see V-268165), so the file has to be
# provisioned for the rule to be loadable at all.
#
# Creating it empty is safe, unlike the cron.allow case in V-268097: lastlog is a sparse
# record file that login tools write into by UID offset, and an empty one simply means "no
# logins recorded yet" — which is true of a freshly installed system anyway. Mode 0644 root:root
# matches what shadow's login creates.
#
# The record produced is of lastlog being updated, not of concurrency being detected;
# correlating the records is the analyst's job, which is what the check actually verifies.
{...}: {
  systemd.tmpfiles.rules = [
    "f /var/log/lastlog 0644 root root -"
  ];

  security.audit.rules = [
    "-w /var/log/lastlog -p wa -k logins"
  ];
}
