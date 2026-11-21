# Drakkar system configuration (desktop)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
  ];

  profiles.ai.enable = true;
  profiles.base.enable = true;
  profiles.communication.enable = true;
  # profiles.creative.enable = true;
  profiles.desktop.enable = true;
  profiles.development.enable = true;
  profiles.gaming.enable = true;

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
  # features.ai.openhands.enable = true;

  features.fleet.comin.enable = true;
  features.fleet.nix-remote-builder-server.enable = true;
  features.fleet.remote-access.enable = true;
  features.monitoring.prometheus-exporter.enable = true;
  features.nixos.graphics.amd.enable = true;
  # The fleet binary cache (GH-147); its cacheKey in common/fleet.nix is filled in
  # from the first start's journal.
  features.nix.vcache.enable = true;
  # vdaemon-proxy (GH-157): every nix-daemon op logged to the journal as JSON.
  # Rollback: lib.mkForce false, or at runtime the fallback keeps Nix reachable.
  features.nix.vdaemon-proxy.enable = true;
  # vverify (Voltaic): the store checked against its database weekly, into node_exporter (GH-158).
  features.nix.vverify.enable = true;
  features.storage.nfs-client.enable = true;
  # vbuild (Voltaic) replaces build-remote as the Nix build hook (GH-156). drakkar
  # has no remote builders, so its visible effect is an immediate decline.
  features.fleet.vbuild.enable = true;
}
