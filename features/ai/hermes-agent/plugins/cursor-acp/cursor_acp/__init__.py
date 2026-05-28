"""
Cursor ACP provider plugin for Hermes Agent.

cursor-acp routes conversations through the `cursor agent acp` subprocess
using the Agent Client Protocol (ACP) — JSON-RPC over stdio.

Architecture:
  - api_mode="chat_completions"  — ACP subprocess uses chat_completions routing
  - base_url="acp://cursor"      — sentinel scheme; not a real HTTP URL.
                                   Hermes sees acp:// and skips the HTTP stack,
                                   handing control to the ACP subprocess layer.
  - auth_type="external_process" — credentials are managed by the ACP subprocess
                                   via ~/.cursor/cli-config.json (existing Cursor
                                   login). Hermes skips all credential checks.
  - env_vars=()                  — no env vars; no CURSOR_API_KEY.

ACP subprocess command (resolved by Hermes from base_url or a command table):
  cursor agent acp

This mirrors plugins/model-providers/copilot-acp/init.py in the Hermes repo
exactly, substituting "copilot" identifiers for "cursor" ones.

Pitfalls:
  - Do NOT add CURSOR_API_KEY checks — Cursor uses OAuth via cli-config.json.
  - Do NOT send HTTP requests to acp://cursor — it is a sentinel, not a URL.
  - The `cursor` CLI must be installed and logged in before this provider works.
    Check: `cursor --version` and ~/.cursor/cli-config.json existence.
"""

import logging

from providers import register_provider
from providers.base import ProviderProfile

logger = logging.getLogger(__name__)


class CursorACPProfile(ProviderProfile):
    """Cursor ACP — external ACP subprocess, no REST models endpoint."""

    def fetch_models(
        self,
        api_key: str | None = None,
        timeout: float = 8.0,
    ) -> list[str] | None:
        """Model listing is handled by the ACP subprocess; return None to skip."""
        return None


cursor_acp = CursorACPProfile(
    name="cursor-acp",
    aliases=("cursor", "cursor-agent", "cursor-acp-agent"),
    # ACP subprocess uses chat_completions routing internally.
    api_mode="chat_completions",
    # No env vars — auth via ~/.cursor/cli-config.json.
    env_vars=(),
    # acp:// is a sentinel. Hermes sees this scheme and routes to the ACP
    # subprocess layer instead of making HTTP requests.
    base_url="acp://cursor",
    # Tells Hermes to skip all credential checks; the subprocess manages auth.
    auth_type="external_process",
)

register_provider(cursor_acp)


def register(ctx) -> None:
    """
    Hermes plugin entry point.

    The provider is registered above at import time via register_provider().
    This function satisfies the hermes_agent.plugins entry-point contract so
    Hermes discovers and loads the module at session start.
    """
    logger.debug("cursor-acp: provider registered (acp://cursor, auth=external_process)")
