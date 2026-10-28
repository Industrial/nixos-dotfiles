# V-268078 (CAT II) — NixOS must enable the built-in firewall.
#
# Fix text: networking.firewall.enable = true;
# Check: `iptables -L | grep nixos-fw-log-refuse`, plus the presence of firewall-panic and
# firewall-panic-off, which NixOS installs as part of the firewall module.
#
# Already satisfied by features/nixos/networking/firewall.nix. Declared here anyway so the
# control is provable from this module set rather than implied by another feature; identical
# bool definitions merge without conflict.
{...}: {
  networking.firewall.enable = true;
}
