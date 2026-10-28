# V-268166 (CAT II) — NixOS must generate audit records when concurrent logons to the same
# account occur from different sources.
#
# Fix text: a write+attribute watch on /var/log/lastlog. The record is of lastlog being
# updated, not of concurrency being detected — correlating the records is the analyst's job,
# which is what the check actually verifies.
{...}: {
  security.audit.rules = [
    "-w /var/log/lastlog -p wa -k logins"
  ];
}
