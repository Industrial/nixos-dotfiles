# V-268099 (CAT II) — Successful/unsuccessful uses of chown, fchown, fchownat and lchown must
# generate an audit record.
#
# Rules transcribed from the fix text. The b32 and b64 lines list the syscalls in a different
# order in the published text; kept verbatim rather than normalised, since the set is what
# matters and divergence from the published rule invites argument with an assessor.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S lchown,fchown,chown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
  ];
}
