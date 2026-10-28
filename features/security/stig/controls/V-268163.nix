# V-268163 (CAT II) — NixOS must generate audit records when successful/unsuccessful attempts
# to modify security objects occur.
#
# Extended-attribute syscalls, transcribed from the fix text. Note the auid filter spelling:
# this control uses `-F auid!=-1` where most neighbours use `-F auid!=unset`. They mean the
# same thing to auditctl; kept as published.
#
# Two rules per architecture: one for ordinary users (auid>=1000) and one for root (auid=0),
# so a root-performed change is not invisible.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod"
    "-a always,exit -F arch=b32 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid=0 -k perm_mod"
    "-a always,exit -F arch=b64 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod"
    "-a always,exit -F arch=b64 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid=0 -k perm_mod"
  ];
}
