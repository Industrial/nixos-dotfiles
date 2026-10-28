# V-268097 (CAT II) — NixOS must generate an audit record for successful/unsuccessful
# modifications to the cron configuration.
#
# Watch paths transcribed from the fix text. Note these are the *Nix* cron locations
# (/var/cron/...), not the /etc/cron.* paths the equivalent RHEL STIG uses — the fix text is
# NixOS-specific here, which is one of the places this STIG earns its keep.
{...}: {
  security.audit.rules = [
    "-w /var/cron/tabs/ -p wa -k services"
    "-w /var/cron/cron.allow -p wa -k services"
    "-w /var/cron/cron.deny -p wa -k services"
  ];
}
