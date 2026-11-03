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
#
# PYTHONPATH MUST BE UNSET, and this is the whole reason this module is not a one-liner.
#
# Observed on drakkar 2026-11-04: `agent-canvas` started, resolved the backend from PyPI,
# then died with
#
#   ModuleNotFoundError: No module named 'pydantic_core._pydantic_core'
#
# and no listener on any port. The agent-server runs from a uv venv on Python 3.14, but the
# traceback showed `pydantic` being imported from
# /nix/store/...-python3.13-pydantic-2.12.5/lib/python3.13/site-packages — a nixpkgs build
# for 3.13. This repo's devenv shell exports a PYTHONPATH of ~130 python3.13 site-packages
# entries (treefmt, commitizen, roam-code, fastmcp and their closures), PYTHONPATH precedes
# a venv's own site-packages in sys.path, so the 3.13 pydantic shadowed the 3.14 one and its
# compiled extension could not load under a 3.14 interpreter.
#
# Anything launched from a devenv shell inherits that, so the failure is not specific to
# OpenHands — it will hit any uv/venv-based Python tool that is not itself on 3.13. Fixing
# it at the wrapper rather than asking the operator to remember `env -u PYTHONPATH` is the
# difference between a tool that works and one that works when you invoke it correctly.
#
# Upstream's wrapper already pins uv and UV_PYTHON; `--unset PYTHONPATH` belongs there too
# and is worth sending to numtide. Until then it lives here.
{
  pkgs,
  inputs,
  ...
}: let
  upstream = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openhands-agent-canvas;

  # PYTHONHOME is not set by the devenv shell today, but it would break the venv the same
  # way if it ever were, and unsetting a variable that is already absent costs nothing.
  agent-canvas = pkgs.symlinkJoin {
    name = "openhands-agent-canvas-wrapped";
    paths = [upstream];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/agent-canvas \
        --unset PYTHONPATH \
        --unset PYTHONHOME
    '';
  };
in {
  environment.systemPackages = [agent-canvas];
}
