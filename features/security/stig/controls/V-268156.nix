# V-268156 (CAT II) — NixOS must require users to reauthenticate when changing roles.
#
# Fix text: security.sudo.wheelNeedsPassword = true;
#
# Already the evaluated value on all four hosts, which is why this was reclassified from
# disruptive to zero-cost during implementation — nothing changes. Declared so the control is
# provable from this module set.
#
# The cost would only appear on a host that had adopted NOPASSWD sudo; this baseline makes that
# a visible conflict rather than a silent compliance failure.
{...}: {
  security.sudo.wheelNeedsPassword = true;
}
