"""
id-hermes-superpowers — Superpowers plugin for Hermes Agent

Entry point discovered by Hermes via the hermes_agent.plugins entry point
declared in pyproject.toml.  register(ctx) is called once at session start.

Skills strategy (Option B):
  The upstream superpowers skills/ tree is pinned via fetchFromGitHub in
  package.nix and installed as id_hermes_superpowers/skills/ inside the
  Python package.  on_session_start symlinks that path into
  ~/.hermes/skills/superpowers/ so every skill appears natively in Hermes
  under the superpowers: namespace (e.g. superpowers:brainstorming).

Adding a tool:
  1. Add a schema dict to schemas.py
  2. Add a handler function to tools.py
  3. Call ctx.register_tool() here
  4. Add the tool name to plugin.yaml provides_tools

Adding a hook:
  1. Add a handler function to tools.py (or hooks.py)
  2. Call ctx.register_hook() here
  3. Add the hook name to plugin.yaml provides_hooks
"""

import logging
import os
from pathlib import Path

from . import schemas, tools  # noqa: F401

logger = logging.getLogger(__name__)

# Path to the upstream skills tree installed by package.nix postInstall.
# Resolves to $out/<site-packages>/id_hermes_superpowers/skills/
_SKILLS_SRC = Path(__file__).parent / "skills"


def _link_skills(**kwargs) -> None:
    """
    on_session_start hook: symlink the pinned upstream skills tree into
    ~/.hermes/skills/superpowers/ so Hermes lists them natively.

    Idempotent — safe to call on every session start.
    """
    hermes_home = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
    skills_root = hermes_home / "skills"
    target = skills_root / "superpowers"

    if not _SKILLS_SRC.exists():
        logger.warning(
            "id-hermes-superpowers: skills source not found at %s — "
            "skipping symlink (was the Nix package built correctly?)",
            _SKILLS_SRC,
        )
        return

    skills_root.mkdir(parents=True, exist_ok=True)

    # Replace stale symlink or missing target atomically.
    if target.is_symlink() and target.resolve() == _SKILLS_SRC.resolve():
        logger.debug("id-hermes-superpowers: skills symlink already current")
        return

    tmp = target.with_suffix(".tmp")
    if tmp.is_symlink() or tmp.exists():
        tmp.unlink()

    tmp.symlink_to(_SKILLS_SRC)
    tmp.rename(target)  # atomic on POSIX

    skill_names = sorted(p.name for p in _SKILLS_SRC.iterdir() if p.is_dir())
    logger.info(
        "id-hermes-superpowers: activated %d skills under superpowers: — %s",
        len(skill_names),
        ", ".join(skill_names),
    )


def register(ctx) -> None:
    """Wire all Superpowers tools and lifecycle hooks into Hermes."""

    # ------------------------------------------------------------------
    # Skills symlink — runs every session start, idempotent.
    # ------------------------------------------------------------------
    ctx.register_hook("on_session_start", _link_skills)

    # ------------------------------------------------------------------
    # Tools — uncomment and extend as workflows are implemented.
    #
    # Example:
    #   ctx.register_tool(
    #       name="sp_brainstorm",
    #       toolset="superpowers",
    #       schema=schemas.SP_BRAINSTORM,
    #       handler=tools.sp_brainstorm,
    #   )
    # ------------------------------------------------------------------

    logger.debug(
        "id-hermes-superpowers: registered (skills hook active, no tools yet)"
    )
