# Remote fleet access — SSH + Tailscale + operator keys + remote desktop
#
# Every host imports this module, so the RustDesk client lands fleet-wide from
# here. The matching signal/relay server is host-specific and is imported
# directly by hosts/mimir (features/fleet/remote-desktop-relay.nix).
{lib, ...}: {
  imports = [
    ../network/ssh
    ../security/tailscale
    ./operator-ssh.nix
    ./remote-desktop.nix
  ];

  # Pull-deploy (comin) removed from tree; push-deploy only.

  # Mesh SSH path (Wave 3 default: Tailscale over open firewall port 22).
  services.tailscale.enable = lib.mkForce true;
}
