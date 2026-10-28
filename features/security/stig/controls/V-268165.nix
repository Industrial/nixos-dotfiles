# V-268165 (CAT II) — NixOS must generate audit records when successful/unsuccessful attempts
# to delete security objects occur.
#
# Fix text asks for execution watches on two binaries:
#
#   -a always,exit -F path=/run/current-system/sw/bin/chage ... -k privileged-chage
#   -a always,exit -F path=/run/current-system/sw/bin/chcon  ... -k perm_mod
#
# Only the chage rule is implemented. The chcon rule is a documented partial exclusion.
#
# chcon is an SELinux tool. This system uses AppArmor — mandated by V-268173, in the same
# STIG — so /run/current-system/sw/bin/chcon does not exist and never will.
#
# An earlier revision of this control kept the chcon rule on the reasoning that an audit rule
# for an absent path is "inert, not an error". **That was wrong, and the VM test proved it.**
# auditctl does not skip a watch whose path is missing; it fails:
#
#   auditctl: Error sending add rule data request (No such file or directory)
#   auditctl: There was an error in line 11 of .../audit.rules
#
# and exits non-zero, so audit-rules-nixos.service fails and NOT ONE rule is loaded. Keeping
# a rule for a file that cannot exist does not add a harmless no-op; it takes down the entire
# audit subsystem, which is the opposite of what this STIG is for. Verified by
# tests/vm/audit.nix: with the chcon rule present, `auditctl -l` returns "No rules".
#
# So the exclusion is not a convenience. The alternative is an unaudited system.
{...}: {
  security.audit.rules = [
    "-a always,exit -F path=/run/current-system/sw/bin/chage -F perm=x -F auid>=1000 -F auid!=unset -k privileged-chage"
  ];
}
