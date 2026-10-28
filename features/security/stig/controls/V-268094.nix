# V-268094 (CAT II) — Successful/unsuccessful uses of the mount syscall must generate an
# audit record.
#
# Rules transcribed from the fix text.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
    "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
  ];
}
