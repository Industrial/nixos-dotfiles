"""
id-hermes-superpowers — Superpowers plugin for Hermes Agent

Entry point discovered by Hermes via the hermes_agent.plugins entry point
declared in pyproject.toml.  register(ctx) is called once at session start.

Adding a tool:
  1. Add a schema dict to schemas.py
  2. Add a handler function to tools.py
  3. Call ctx.register_tool() here
  4. Add the tool name to plugin.yaml provides_tools

Adding a hook:
  1. Add a handler function below (or in a hooks.py module)
  2. Call ctx.register_hook() here
  3. Add the hook name to plugin.yaml provides_hooks
"""

import logging

from . import schemas, tools  # noqa: F401 — imported for side-effect registration

logger = logging.getLogger(__name__)


def register(ctx) -> None:
    """Wire all Superpowers tools and lifecycle hooks into Hermes."""

    # ------------------------------------------------------------------
    # Tools
    # Uncomment and extend as workflows are implemented.
    # Example:
    #
    #   ctx.register_tool(
    #       name="sp_brainstorm",
    #       toolset="superpowers",
    #       schema=schemas.SP_BRAINSTORM,
    #       handler=tools.sp_brainstorm,
    #   )
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # Hooks
    # Uncomment and extend as cross-cutting concerns are identified.
    # Available events:
    #   pre_tool_call, post_tool_call
    #   pre_llm_call,  post_llm_call
    #   on_session_start, on_session_end
    #
    # Example:
    #
    #   ctx.register_hook("on_session_start", tools.on_session_start)
    # ------------------------------------------------------------------

    logger.debug("id-hermes-superpowers: registered (no tools active yet)")
