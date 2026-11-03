# Fleet remote desktop — RustDesk client (all hosts).
#
# Pairs with features/fleet/remote-desktop-relay.nix, which runs the signal
# (hbbs) and relay (hbbr) servers on mimir. Clients reach them over MagicDNS
# at `mimir`, the same way features/fleet/nix-remote-builder-* address the
# fleet by bare hostname.
#
# Tailnet-only by construction: features/security/tailscale marks tailscale0 a
# trusted interface, so the RustDesk ports are reachable between fleet hosts
# and are never opened on any other interface. Nothing here publishes a port.
#
# Screen capture works because the desktop profile already brings up PipeWire
# (features/nixos/sound) and xdg-desktop-portal-hyprland
# (features/window-manager/hyprland) — RustDesk needs both under Wayland.
#
# One-time pairing step: hbbs generates its keypair on first start, so the
# public key cannot be known at build time and is deliberately not baked in.
# After the relay host is deployed, read it off mimir and enter it once per
# client under Settings -> Network (ID/Relay server = mimir):
#
#   ssh mimir -- sudo cat /var/lib/rustdesk/id_ed25519.pub
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    rustdesk
  ];
}
