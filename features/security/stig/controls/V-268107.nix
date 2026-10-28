# V-268107 (CAT II) — NixOS must have the packages required for offloading audit logs
# installed and running.
#
# Fix text: services.journald.audit = true;
#
# That option has been RENAMED. Current nixpkgs emits:
#
#   evaluation warning: The option `services.journald.audit' has been renamed to
#   `services.journald.settings.Journal.Audit'.
#
# It still resolves through the alias today, but writing a baseline against a renamed option
# is how it breaks on a future bump — the same reasoning as the openssh settings in V-268088
# and friends, and the same lesson V-268150 taught the hard way when
# services.timesyncd.extraConfig turned out to be removed outright rather than renamed.
#
# Routing kernel audit messages into the journal is what makes them available to journald's
# upload mechanism; the actual offloading is V-268108 and V-268109, which need a remote
# endpoint and live in the full profile.
#
# The check verifies systemd-journald is active and running, despite the requirement's
# wording about packages.
{...}: {
  services.journald.settings.Journal.Audit = true;
}
