# V-268181 (CAT II) — NixOS must define default permissions for all authenticated users in
# such a way that the user can only read and modify their own files.
#
# Fix text: security.loginDefs.settings.UMASK = "077";
#
# 077 means new files are created mode 0600 and directories 0700 — owner-only.
#
# nixpkgs already defaults UMASK to 077 (verified by evaluating a bare system), so this control
# changes nothing on these hosts. It is declared anyway so the report proves the value instead
# of inheriting it from a default a later nixpkgs could relax.
#
# Zero-cost here because this fleet has no shared-group workflow. It would be disruptive on a
# host where users collaborate through group-writable directories — worth knowing before
# copying this profile elsewhere.
{...}: {
  security.loginDefs.settings.UMASK = "077";
}
