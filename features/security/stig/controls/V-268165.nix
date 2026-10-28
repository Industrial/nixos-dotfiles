# V-268165 (CAT II) — NixOS must generate audit records when successful/unsuccessful attempts
# to delete security objects occur.
#
# Fix text watches execution of chage and chcon, both on NixOS profile paths.
#
# Note: chcon is an SELinux tool. NixOS uses AppArmor (V-268173), so that binary will not
# normally be present and its rule will never fire. Transcribed as published — an audit rule
# for an absent path is inert, not an error, and deviating from the published rule invites
# argument with an assessor. Flagged for the report's justification column.
{...}: {
  security.audit.rules = [
    "-a always,exit -F path=/run/current-system/sw/bin/chage -F perm=x -F auid>=1000 -F auid!=unset -k privileged-chage"
    "-a always,exit -F path=/run/current-system/sw/bin/chcon -F perm=x -F auid>=1000 -F auid!=unset -k perm_mod"
  ];
}
