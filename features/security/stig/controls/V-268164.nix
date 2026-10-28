# V-268164 (CAT II) — NixOS must generate audit records when successful/unsuccessful attempts
# to delete privileges occur.
#
# Fix text watches execution of usermod. The path is the NixOS one
# (/run/current-system/sw/bin/usermod) rather than /usr/sbin/usermod — another place the fix
# text is genuinely NixOS-aware.
{...}: {
  security.audit.rules = [
    "-a always,exit -F path=/run/current-system/sw/bin/usermod -F perm=x -F auid>=1000 -F auid!=unset -k privileged-usermod"
  ];
}
