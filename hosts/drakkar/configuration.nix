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

    # OpenHands Agent Canvas, drakkar only — DISABLED in favour of
    # features/ai/paseo (profiles/ai.nix), which is now the single browser surface
    # over this host's coding agents. Agent Canvas is the same category: a web UI
    # driving agent CLIs, on 127.0.0.1:8000.
    #
    # Commented rather than deleted, because its feature carries findings worth
    # keeping — the PYTHONPATH collision this repo's devenv shell causes for any
    # uv/venv tool, and the CLAUDE_CODE_EXECUTABLE fix for the agent SDK's
    # generic-linux `claude`. Read that header before re-enabling anything that
    # drives Claude Code through uvx.
    #
    # Paseo is preferred over it on three counts: packaged in nixpkgs rather than
    # pulled from a third-party flake, hermetic rather than fetching its backend
    # from PyPI on first run, and a declarative service rather than a
    # run-it-yourself CLI.
    # ../../features/ai/openhands

    ../../features/fleet/comin.nix
    ../../features/fleet/nix-remote-builder-server.nix
    ../../features/fleet/remote-access.nix
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/storage/nfs-client
  ];
}
