# V-268157 (CAT I) — NixOS must implement cryptographic mechanisms to protect the integrity of
# nonlocal maintenance and diagnostic communications.
#
# Fix text: services.openssh.macs = [ "hmac-sha2-512" "hmac-sha2-256" ];
#
# `services.openssh.macs` resolves only through a mkRenamedOptionModule alias (sshd.nix line
# 212). Canonical option is `services.openssh.settings.Macs`, used here.
#
# Note both these MACs are plain hmac, not the encrypt-then-MAC `-etm@openssh.com` variants
# that OpenSSH prefers by default. This control therefore *narrows* sshd to the weaker-ordered
# set, which is a case of compliance and best practice pointing in different directions. The
# requirement is an explicit list, so the list is what is configured; noted for the report's
# justification column.
{...}: {
  services.openssh.settings.Macs = [
    "hmac-sha2-512"
    "hmac-sha2-256"
  ];
}
