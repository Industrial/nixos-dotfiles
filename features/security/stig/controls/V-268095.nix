# V-268095 (CAT II) — Successful/unsuccessful uses of rename, unlink, rmdir, renameat and
# unlinkat must generate an audit record.
#
# Rules transcribed from the fix text.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"
    "-a always,exit -F arch=b64 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"
  ];
}
