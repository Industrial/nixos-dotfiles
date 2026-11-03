# OpenHands Agent Canvas — self-hosted control centre for coding agents.
#
# Agent Canvas drives agents over the Agent Client Protocol (ACP): the Agent Server spawns
# an agent's own CLI as a subprocess and relays each turn to it, rather than calling an LLM
# itself. The agent to point it at here is Claude Code, which reads the existing
# subscription login from ~/.claude/.credentials.json — so no API key belongs in this
# module, and none is set. (Containerised backends have no host login and take
# CLAUDE_CODE_OAUTH_TOKEN instead; that is not this shape.)
#
# NOT FROM NIXPKGS, DELIBERATELY. OpenHands is absent from nixpkgs entirely — verified
# 2026-11-04 against this repo's pin, nixos-unstable and master, with no packaging PR open.
# `inputs.llm-agents` is numtide's package set for coding agents, MIT, auto-updated daily.
# The alternative community flake (luochen1990/OpenHands-flake) ships a NixOS module but
# packages openhands 0.39.1 — the legacy pre-Canvas application, which has no ACP backend
# and therefore cannot run Claude Code at all.
#
# WHAT THIS DOES NOT GIVE YOU: hermeticity. The packaged binary is the npm launcher. It
# still fetches the Python backend (openhands-agent-server, openhands-automation) from PyPI
# via uvx on first start. numtide's wrapper pins `uv` and sets UV_PYTHON to the nixpkgs
# interpreter, which fixes the worst of it — unpinned, uvx downloads the newest CPython
# whenever it finds no suitable interpreter, and upstream's own config/defaults.json records
# that breaking every autumn until their compiled dependencies publish wheels for the new
# release. But first run needs the network, and the backend version is not in the closure.
#
# If that matters more than the convenience, the hermetic shape is the container:
# ghcr.io/openhands/agent-server:<version>-python needs no PyPI at runtime and pre-installs
# the ACP CLI wrappers, rewriting `npx -y <pkg>` to pinned in-image binaries. That is a
# different feature and would have to run on the rootless daemon
# (features/nixos/docker/default.nix — there is no /var/run/docker.sock on these hosts).
#
# Canvas binds 127.0.0.1:8000 by default and keeps its state in ~/.openhands. Nothing here
# opens a port or installs a service: this is the CLI, run on demand as `agent-canvas`.
# Making it a systemd.user service is a separate decision and needs the state directory and
# the session key thought through first.
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openhands-agent-canvas
  ];
}
