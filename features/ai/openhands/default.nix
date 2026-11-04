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
# Canvas binds 127.0.0.1:8000 by default. Nothing here opens a port or installs a service:
# this is the CLI, run on demand as `agent-canvas`. Making it a systemd.user service is a
# separate decision and needs the state directory and the session key thought through first.
#
#
# CONFIGURATION IS DECLARATIVE, BUT NOT FROM THIS MODULE, because OpenHands splits its
# config across three tiers with different writability and only one of them is Nix-shaped.
#
#   Tier 1 — agent-server infrastructure. `load_config()` (agent_server/config.py) reads a
#   JSON file named by OPENHANDS_AGENT_SERVER_CONFIG_PATH, overlays OH_* env vars on top,
#   and never writes back; the model is `frozen`. This is the only tier a Nix-store path
#   would survive, and nothing here needs changing from its defaults yet — notably
#   `acp_skill_sourcing = "native"`, which is what makes the ACP CLI read the host's own
#   ~/.claude and the repository instead of OpenHands injecting its managed skills.
#
#   Tier 2 — user settings, ~/.openhands. The substantive tier: which agent backend, which
#   model, MCP config, iteration limits, enabled skills. `agent-canvas --help` says it
#   outright — "LLM settings are configured through the web UI settings page, not
#   environment variables" — so the server owns the file and writes it back through
#   `_atomic_write_json`, whose final `tmp.replace(path)` would replace a file symlink with
#   a regular file. bin/link-files-nixos therefore links the DIRECTORY: ~/.openhands ->
#   ./.openhands, so UI changes land in the payload as an ordinary git diff. Secrets and
#   runtime state live in that directory too and are gitignored; see ./.gitignore.
#
#   Tier 3 — repository config, discovered relative to the workspace working directory.
#   /.openhands at the dotfiles root is a tracked symlink to ./project, mirroring how
#   /.claude is a tracked symlink to .claude-setup/.claude. No activation step: the link is
#   inside the repo, so committing it is what reproduces it. See ./project/README.md.
#
# bin/check-payload asserts the invariants that hold this together — no secret tracked, the
# active profile committed, the backend still acp/claude-code, acp_isolate_data_dir still
# false. Run it after touching the payload.
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
#
#
# CLAUDE_CODE_EXECUTABLE MUST POINT AT THE NIXPKGS CLAUDE, for the second NixOS-specific
# reason this module exists.
#
# With PYTHONPATH fixed, Canvas started and the ACP bridge connected, but every attempt to
# open a Claude Code conversation failed with
#
#   ERROR Failed to start ACP server: Internal error   acp_agent.py:2319
#   acp.exceptions.RequestError: Internal error
#
# which is JSON-RPC -32603 and says nothing. Driving the bridge directly over stdio gave the
# real message:
#
#   Claude Code process exited with code 127. stderr: Could not start dynamically linked
#   executable: ~/.npm/_npx/<hash>/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64/claude
#   NixOS cannot run dynamically linked executables intended for generic linux environments
#
# The bridge depends on @anthropic-ai/claude-agent-sdk, which ships its own prebuilt `claude`
# for linux-x64 with interpreter /lib64/ld-linux-x86-64.so.2. That path exists here but is
# nixpkgs' stub-ld, whose entire job is to fail with that message, so the child exits 127 and
# the bridge reports a generic internal error. nixpkgs' own claude-code is the same program
# correctly patched for this system, so the fix is to tell the SDK to use it instead of the
# binary it downloaded.
#
# `--set-default`, not `--set`: a developer pointing at a local Claude build should be able to
# override it from the environment without editing this file.
#
# This makes claude-code a hard runtime dependency of this feature, which is honest — Agent
# Canvas without a working agent backend is a UI with nothing behind it. features/ai/claude-code
# installs the same package for interactive use; referencing it here is what keeps it in
# drakkar's closure even if that feature is ever disabled.
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
        --unset PYTHONHOME \
        --set-default CLAUDE_CODE_EXECUTABLE ${pkgs.claude-code}/bin/claude
    '';
  };
in {
  environment.systemPackages = [agent-canvas];
}
