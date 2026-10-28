# V-268113 (CAT II) — NixOS audit log directory must have a mode of 0700 or less permissive.
#
# The fix text is imperative: `sudo chmod 0700 /var/log/audit`. That is not a thing you do on
# NixOS, because nothing would keep it true. The declarative equivalent for ownership and
# modes on mutable state paths is systemd-tmpfiles, which reasserts the line on every boot and
# on every activation.
#
# This one tmpfiles line carries mode, owner and group for the directory, so it also satisfies
# the directory half of V-268111 (owner root) and V-268112 (group root). Those controls are
# verify-only and point here; splitting the same path across three controls would emit
# duplicate tmpfiles lines for one path, which systemd warns about and which leaves no single
# owner for the state.
{...}: {
  systemd.tmpfiles.rules = [
    "d /var/log/audit 0700 root root -"
  ];
}
