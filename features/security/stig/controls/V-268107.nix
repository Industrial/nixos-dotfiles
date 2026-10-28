# V-268107 (CAT II) — NixOS must have the packages required for offloading audit logs
# installed and running.
#
# Fix text: services.journald.audit = true;
#
# This routes kernel audit messages into the journal, which is what makes them available to
# journald's upload mechanism — the actual offloading is V-268108 and V-268109, which need a
# remote endpoint and are therefore in the full profile, not here.
#
# The check verifies systemd-journald is active and running rather than looking for a package,
# despite the requirement's wording about packages.
{...}: {
  services.journald.audit = true;
}
