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
  # vdeploy (Voltaic), OBSERVE mode next to comin (GH-159): plans and logs the switch to
  # main, never makes it; comin still deploys. Rollback: lib.mkForce false.
  features.nix.vdeploy.enable = true;
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
  # ... in conformance mode (GH-183): native answers checked against the daemon's, which
  # clients still get. Counters: /run/vdaemon-proxy/conformance.prom. Rollback: delete.
  features.nix.vdaemon-proxy.conformance = true;
  # ... and answering these itself (GH-183): the ops with 0 diffs in 133,768 real checks;
  # QueryValidPaths after 311 matches and 0 diffs in the shadow (GH-224).
  # Kill switch (root): touch /run/vdaemon-proxy/forward-all. Rollback: lib.mkForce [].
  features.nix.vdaemon-proxy.native = ["IsValidPath" "QueryPathInfo" "QueryValidPaths"];
  # vverify (Voltaic): the store checked against its database weekly, into node_exporter (GH-158).
  features.nix.vverify.enable = true;
  # vbump (Voltaic): per-input flake.lock bumps, one PR each; bin/update/flake runs it (GH-189).
  features.cli.vbump.enable = true;
  # vfetch, the concurrent closure fetcher vdeploy (#159) calls (GH-155), as a CLI.
  features.cli.vfetch.enable = true;
  # vfetch serve: the first substituter, so every substitution here fetches through
  # vfetch (GH-155). Rollback: `lib.mkForce false`, and Nix substitutes directly.
  features.nix.vfetch.enable = true;
  # vfiles (Voltaic): declared dotfiles placed by one linker, not 16 activation scripts (GH-188).
  # Rollback: lib.mkForce false brings the scripts back.
  features.nixos.vfiles.enable = true;
  # vgen (Voltaic) owns generation retention and the boot entries; vgc only collects (GH-190).
  features.nixos.vgen.enable = true;
  # vhealth (Voltaic): the probes drakkar's features declare (vcache, node_exporter, sshd,
  # vverify's metrics), checked every minute into node_exporter; `vhealth check` (GH-180).
  features.nix.vhealth.enable = true;
  features.storage.nfs-client.enable = true;
  # vbuild (Voltaic) replaces build-remote as the Nix build hook (GH-156). drakkar
  # has no remote builders, so its visible effect is an immediate decline.
  features.fleet.vbuild.enable = true;
  # userborn writes /etc/passwd, group and shadow in place of update-users-groups.pl
  # (GH-187). Root is locked: switch over and roll back per docs/runbooks/userborn.md.
  # Rollback: set it to false, then userdel any user created while it was on.
  features.nixos.users.userborn.enable = true;
}
