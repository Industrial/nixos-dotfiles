# V-268159 (CAT I) — NixOS must protect the confidentiality and integrity of transmitted
# information.
#
# Fix text: services.sshd.enable = true;
#
# `services.sshd.enable` is a legacy alias (sshd.nix line 183, mkAliasOptionModule to
# `services.openssh.enable`). It works, but writing new configuration against an alias is how
# a baseline breaks on a future nixpkgs bump. Canonical option used here.
#
# Already enabled by features/network/ssh; identical bool definitions merge without conflict.
# Note the requirement is satisfied by SSH being the transport, not by enabling SSH per se —
# the confidentiality and integrity properties come from V-268089 (ciphers) and V-268157
# (MACs), which narrow what that transport will negotiate.
{...}: {
  services.openssh.enable = true;
}
