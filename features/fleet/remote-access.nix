# Remote fleet access — SSH + Tailscale + operator keys
{lib, ...}: {
  imports = [
    ../network/ssh
    ../security/tailscale
    ./operator-ssh.nix
  ];

  # Pull-deploy (comin) removed from tree; push-deploy only.

  # Mesh SSH path (Wave 3 default: Tailscale over open firewall port 22).
  services.tailscale.enable = lib.mkForce true;
}
