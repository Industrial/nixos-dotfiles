# Drakkar system configuration (desktop)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix

    ../../profiles/ai.nix
    ../../profiles/base.nix
    ../../profiles/communication.nix
    #../../profiles/creative.nix
    ../../profiles/desktop.nix
    ../../profiles/development.nix
    ../../profiles/gaming.nix

    # OpenHands Agent Canvas, drakkar only. profiles/ai.nix carries it as a commented
    # opt-in because muninn imports that profile as well; this is the desktop, so this is
    # where it lands. Run it on demand as `agent-canvas` (binds 127.0.0.1:8000, state in
    # ~/.openhands). First start fetches the Python backend from PyPI via uvx — see the
    # feature's header for why that is not hermetic and what the alternative costs.
    ../../features/ai/openhands

    ../../features/fleet/comin.nix
    ../../features/fleet/nix-remote-builder-server.nix
    ../../features/fleet/remote-access.nix
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/storage/nfs-client
  ];
}
