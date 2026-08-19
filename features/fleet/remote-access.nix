# Remote fleet access — SSH + Tailscale
{lib, ...}: {
  imports = [
    ../network/ssh
    ../security/tailscale
  ];

  # Pull-deploy (comin) removed from tree; push-deploy only.

  # Mesh SSH path (Wave 3 default: Tailscale over open firewall port 22).
  services.tailscale.enable = lib.mkForce true;
}
