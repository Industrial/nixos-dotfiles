# V-268100 (CAT II) — Successful/unsuccessful uses of chmod, fchmod and fchmodat must generate
# an audit record.
#
# Rules transcribed from the fix text. Uses the `-k` shorthand where the neighbouring V-268099
# uses `-F key=`; both are accepted by auditctl and both are kept as published.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod"
    "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod"
  ];
}
