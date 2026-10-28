# V-268112 (CAT II) — NixOS audit directory and logs must be group-owned by root to prevent
# unauthorized read access.
#
# VERIFY-ONLY. Emits nothing, deliberately.
#
# Same shape as V-268111, for the group field rather than the owner field. The fix text is
# `sudo chown -R :root /var/log/audit`; the group is already root through the tmpfiles lines
# declared by V-268113 (directory) and V-268114 (log file).
{...}: {
  # Intentionally empty — see above and ./V-268112.assay.nix.
}
