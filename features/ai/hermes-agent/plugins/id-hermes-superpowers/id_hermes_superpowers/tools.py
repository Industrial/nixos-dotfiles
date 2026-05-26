"""
tools.py — Tool handlers for id-hermes-superpowers

Each handler is a plain Python function with the signature:

    def handler(params: dict, **kwargs) -> str:
        ...
        return json.dumps({"success": True, ...})

  params   — the arguments the LLM passed (validated against the schema)
  kwargs   — Hermes-injected context: task_id, session, agent, etc.

Return value must be a JSON string.  On error, return a JSON object with
{"success": False, "error": "<message>"} rather than raising.

Naming convention:  sp_<toolname>

Hook handlers have a different signature depending on the event — see the
Hermes plugin docs for the exact keyword arguments each hook event injects.

Example tool handler:

    import json

    def sp_brainstorm(params: dict, **kwargs) -> str:
        topic    = params.get("topic", "")
        issue_id = params.get("issue_id", "")
        # ... workflow logic ...
        return json.dumps({"success": True, "design_path": str(design_path)})

Example hook handler:

    def on_session_start(**kwargs) -> None:
        task_id = kwargs.get("task_id", "unknown")
        logger.info("Superpowers session started: %s", task_id)
"""

import logging

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Tool handlers — add below as workflows are implemented
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Hook handlers — add below as cross-cutting concerns are identified
# ---------------------------------------------------------------------------
