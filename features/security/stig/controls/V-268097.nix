# V-268097 (CAT II) — NixOS must generate an audit record for successful/unsuccessful
# modifications to the cron configuration.
#
# Fix text asks for three watches:
#
#   -w /var/cron/tabs/      -p wa -k services
#   -w /var/cron/cron.allow -p wa -k services
#   -w /var/cron/cron.deny  -p wa -k services
#
# These are the NixOS cron paths rather than the FHS /etc/cron.* ones, which is the fix text
# being genuinely NixOS-aware. But auditctl FAILS THE ENTIRE RULES FILE on a watch whose path
# does not exist (see V-268165 for the evidence), and none of these three exists on a stock
# system: /var/cron/tabs appears only once cron has run, and cron.allow / cron.deny are
# absent by design.
#
# So only the directory is watched, and this control provisions it.
#
# cron.allow and cron.deny are a documented partial exclusion, and the reason is not
# squeamishness about diverging from the fix text — it is that satisfying it literally would
# change the system's authorization semantics. An EMPTY /var/cron/cron.allow does not mean
# "no allow-list configured"; to cron it means "no user may use cron". Creating the file to
# satisfy an audit watch would silently revoke crontab access for every user, including the
# nix-gc and store-optimise jobs in features/nixos/systemd. An empty cron.deny is harmless but
# pointless on its own.
#
# Watching the directory does cover the requirement's intent: crontabs live in
# /var/cron/tabs, and `-p wa` on the directory records creation, modification and deletion of
# any file inside it.
{...}: {
  # The watch target has to exist before auditctl loads the rule, hence tmpfiles rather than
  # relying on cron to create it. Mode and ownership match what the cron package expects.
  systemd.tmpfiles.rules = [
    "d /var/cron 0755 root root -"
    "d /var/cron/tabs 0700 root root -"
  ];

  security.audit.rules = [
    "-w /var/cron/tabs -p wa -k services"
  ];
}
