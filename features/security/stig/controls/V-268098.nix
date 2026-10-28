# V-268098 (CAT II) — NixOS must generate an audit record for successful/unsuccessful uses of
# truncate, ftruncate, creat, open, openat and open_by_handle_at.
#
# Rules transcribed from the fix text. Only permission-denied outcomes are audited
# (-F exit=-EACCES and -F exit=-EPERM); auditing every open() would flood the log. Note the
# fix text uses `-F key=access` here rather than the `-k` shorthand used by neighbouring
# controls — kept verbatim.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -F key=access"
    "-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -F key=access"
    "-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -F key=access"
    "-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -F key=access"
  ];
}
