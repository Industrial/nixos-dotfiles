# V-268078 (CAT II) — NixOS must enable the built-in firewall.
#
# Fix text: networking.firewall.enable = true;
# Check: `iptables -L | grep nixos-fw-log-refuse`, plus the presence of firewall-panic and
# firewall-panic-off.
#
# Half of that check is unsatisfiable on a current NixOS. `firewall-panic` and
# `firewall-panic-off` NO LONGER EXIST — grepping nixos/modules for the name returns nothing,
# and firewall-iptables.nix now installs `pkgs.nixos-firewall-tool`, which carries the same
# capability as `nixos-firewall-tool panic`. No configuration can make the published check
# pass; the distribution renamed the tool. The VM test asserts the successor and records the
# rename for the report's justification column.
#
# Already satisfied by features/nixos/networking/firewall.nix. Declared here anyway so the
# control is provable from this module set rather than implied by another feature; identical
# bool definitions merge without conflict.
{...}: {
  networking.firewall.enable = true;
}
