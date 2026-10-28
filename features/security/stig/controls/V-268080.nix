# V-268080 (CAT II) — NixOS must enable the audit daemon.
#
# Fix text: both halves are required — `security.auditd.enable` runs the userspace daemon that
# writes /var/log/audit, `security.audit.enable` loads the kernel rule set. Enabling only one
# produces a system that looks audited and is not.
#
# The only cost is log volume; nothing interactive changes.
{...}: {
  security.auditd.enable = true;
  security.audit.enable = true;
}
