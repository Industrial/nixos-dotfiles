# V-268111 (CAT II) — NixOS audit directory and logs must be owned by root to prevent
# unauthorized read access.
#
# VERIFY-ONLY. Emits nothing, deliberately.
#
# The fix text is `sudo chown -R root /var/log/audit`, which covers both the directory and the
# log file. Both are already owned by root through the tmpfiles lines that V-268113 (directory)
# and V-268114 (log file) declare, each of which carries the owner field.
#
# systemd.tmpfiles.rules is a list keyed by path at runtime: emitting a second line for
# /var/log/audit here would be a duplicate path declaration with no single owner. So the
# ownership claim is verified in the colocated suite against those two controls instead.
{...}: {
  # Intentionally empty — see above and ./V-268111.assay.nix.
}
