"""PLUGIN_NAME — Hermes plugin entry point."""
import logging
from . import schemas, tools  # noqa: F401

logger = logging.getLogger(__name__)


def register(ctx) -> None:
    # ctx.register_tool(name="...", toolset="...", schema=schemas.X, handler=tools.x)
    # ctx.register_hook("on_session_start", tools.on_session_start)
    logger.debug("PLUGIN_NAME: registered (no tools active yet)")
