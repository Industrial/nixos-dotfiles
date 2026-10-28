# V-268114 (CAT II) — NixOS audit logs must have a mode of 0600 or less permissive.
#
# Imperative fix text (`sudo chmod 0600 /var/log/audit/audit.log`) made declarative with
# systemd-tmpfiles. The `z` type adjusts an existing path's mode, owner and group without
# creating it — auditd creates its own log, so creating it here would be wrong.
#
# This line carries owner and group too, so it also satisfies the log-file half of V-268111
# and V-268112, which are verify-only and point here.
{...}: {
  systemd.tmpfiles.rules = [
    "z /var/log/audit/audit.log 0600 root root -"
  ];
}
