# V-268091 (CAT II) — NixOS must generate audit records for all usage of privileged commands.
#
# Rules transcribed from the fix text. Two trailing spaces inside the gid/egid rule strings in
# the published fix text are dropped; auditctl normalises whitespace and the check matches on
# the rule fields, not the literal line.
#
# security.audit.rules is a list, so each control contributes its own rules and they merge.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
    "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
    "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv"
    "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv"
  ];
}
