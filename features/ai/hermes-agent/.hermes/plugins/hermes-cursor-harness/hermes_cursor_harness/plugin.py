"""Hermes registration glue."""

from __future__ import annotations

import json
import logging
import shlex
from typing import Any

from . import schemas, tools

logger = logging.getLogger(__name__)


def register(ctx: Any) -> None:
    ctx.register_tool(
        name="cursor_harness_run",
        toolset="cursor_harness",
        schema=schemas.RUN_SCHEMA,
        handler=tools.cursor_harness_run,
        description="Run a Cursor-powered Hermes harness turn.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_status",
        toolset="cursor_harness",
        schema=schemas.STATUS_SCHEMA,
        handler=tools.cursor_harness_status,
        description="List Cursor harness sessions.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_events",
        toolset="cursor_harness",
        schema=schemas.EVENTS_SCHEMA,
        handler=tools.cursor_harness_events,
        description="Read Cursor harness event history.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_doctor",
        toolset="cursor_harness",
        schema=schemas.DOCTOR_SCHEMA,
        handler=tools.cursor_harness_doctor,
        description="Check Cursor harness installation.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_models",
        toolset="cursor_harness",
        schema=schemas.MODELS_SCHEMA,
        handler=tools.cursor_harness_models,
        description="List available Cursor Agent models.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_sdk",
        toolset="cursor_harness",
        schema=schemas.SDK_SCHEMA,
        handler=tools.cursor_harness_sdk,
        description="Check or query the official Cursor SDK bridge.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_latest",
        toolset="cursor_harness",
        schema=schemas.LATEST_SCHEMA,
        handler=tools.cursor_harness_latest,
        description="Show latest Cursor harness session.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_install_companion",
        toolset="cursor_harness",
        schema=schemas.INSTALL_COMPANION_SCHEMA,
        handler=tools.cursor_harness_install_companion,
        description="Install Cursor-side MCP/rules/skills companion files.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_smoke",
        toolset="cursor_harness",
        schema=schemas.SMOKE_SCHEMA,
        handler=tools.cursor_harness_smoke,
        description="Run Hermes Cursor Harness self-tests.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_background_agent",
        toolset="cursor_harness",
        schema=schemas.BACKGROUND_AGENT_SCHEMA,
        handler=tools.cursor_harness_background_agent,
        description="Manage Cursor Background Agents.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_provider_route",
        toolset="cursor_harness",
        schema=schemas.PROVIDER_ROUTE_SCHEMA,
        handler=tools.cursor_harness_provider_route,
        description="Validate Hermes core cursor/* provider-route support.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_diagnostics",
        toolset="cursor_harness",
        schema=schemas.DIAGNOSTICS_SCHEMA,
        handler=tools.cursor_harness_diagnostics,
        description="Create a redacted Cursor harness diagnostic bundle.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_compatibility",
        toolset="cursor_harness",
        schema=schemas.COMPATIBILITY_SCHEMA,
        handler=tools.cursor_harness_compatibility,
        description="Run or list Cursor harness compatibility records.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_config",
        toolset="cursor_harness",
        schema=schemas.CONFIG_SCHEMA,
        handler=tools.cursor_harness_config,
        description="Validate Cursor harness configuration.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_session",
        toolset="cursor_harness",
        schema=schemas.SESSION_SCHEMA,
        handler=tools.cursor_harness_session,
        description="Manage Cursor harness sessions.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_security_profiles",
        toolset="cursor_harness",
        schema=schemas.SECURITY_PROFILES_SCHEMA,
        handler=tools.cursor_harness_security_profiles,
        description="List Cursor harness security profiles.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_approvals",
        toolset="cursor_harness",
        schema=schemas.APPROVALS_SCHEMA,
        handler=tools.cursor_harness_approvals,
        description="List or decide pending Cursor harness approvals.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_proposals",
        toolset="cursor_harness",
        schema=schemas.PROPOSALS_SCHEMA,
        handler=tools.cursor_harness_proposals,
        description="List or resolve Cursor-to-Hermes proposals.",
        emoji="⌁",
    )
    ctx.register_tool(
        name="cursor_harness_proposal_inbox",
        toolset="cursor_harness",
        schema=schemas.PROPOSAL_INBOX_SCHEMA,
        handler=tools.cursor_harness_proposal_inbox,
        description="Show Cursor-to-Hermes proposal inbox.",
        emoji="⌁",
    )
    if hasattr(ctx, "register_command"):
        ctx.register_command(
            "cursor-harness",
            _slash_cursor_harness,
            description="Control the Hermes Cursor Harness",
            args_hint="[doctor|status|models|latest]",
        )
    if hasattr(ctx, "register_skill"):
        try:
            from pathlib import Path

            package_skill = Path(__file__).resolve().parent / "skills" / "cursor-harness.md"
            source_tree_skill = Path(__file__).resolve().parent.parent / "skills" / "cursor-harness.md"
            ctx.register_skill("cursor-harness", package_skill if package_skill.exists() else source_tree_skill)
        except Exception:
            logger.debug("cursor-harness skill registration failed", exc_info=True)
    logger.info("hermes-cursor-harness registered")


def _slash_cursor_harness(raw_args: str) -> str:
    parts = shlex.split(raw_args or "")
    command = parts[0] if parts else "status"
    rest = parts[1:]
    if command in {"doctor", "check"}:
        return tools.cursor_harness_doctor({})
    if command in {"status"}:
        return tools.cursor_harness_status({})
    if command in {"models", "model"}:
        return tools.cursor_harness_models({})
    if command in {"sdk"}:
        action = rest[0] if rest else "status"
        return tools.cursor_harness_sdk({"action": action})
    if command in {"latest", "last"}:
        project = rest[0] if rest else ""
        return tools.cursor_harness_latest({"project": project} if project else {})
    if command in {"smoke", "selftest"}:
        level = rest[0] if rest else "quick"
        project = rest[1] if len(rest) > 1 else ""
        return tools.cursor_harness_smoke({"level": level, "project": project} if project else {"level": level})
    if command in {"diagnostics", "diagnose"}:
        return tools.cursor_harness_diagnostics({})
    if command in {"compat", "compatibility"}:
        return tools.cursor_harness_compatibility({"action": rest[0]} if rest else {"action": "list"})
    if command in {"config", "validate"}:
        action = rest[0] if rest else "validate"
        return tools.cursor_harness_config({"action": action})
    if command in {"sessions", "session"}:
        return tools.cursor_harness_session({"action": rest[0]} if rest else {"action": "list"})
    if command in {"profiles", "security"}:
        return tools.cursor_harness_security_profiles({})
    if command in {"approvals", "approval"}:
        action = rest[0] if rest else "list"
        request_id = rest[1] if len(rest) > 1 else ""
        return tools.cursor_harness_approvals({"action": action, "request_id": request_id} if request_id else {"action": action})
    if command in {"proposals", "proposal"}:
        action = rest[0] if rest else "list"
        proposal_id = rest[1] if len(rest) > 1 else ""
        return tools.cursor_harness_proposals({"action": action, "proposal_id": proposal_id} if proposal_id else {"action": action})
    if command in {"inbox", "proposal-inbox"}:
        return tools.cursor_harness_proposal_inbox({})
    if command in {"provider-route", "provider"}:
        hermes_root = rest[1] if len(rest) > 1 else ""
        return tools.cursor_harness_provider_route({"action": rest[0] if rest else "status", "hermes_root": hermes_root})
    if command in {"background", "bg"}:
        action = rest[0] if rest else "list"
        agent_id = rest[1] if len(rest) > 1 else ""
        return tools.cursor_harness_background_agent({"action": action, "agent_id": agent_id} if agent_id else {"action": action})
    if command in {"events", "event"} and rest:
        limit = int(rest[1]) if len(rest) > 1 else 40
        return tools.cursor_harness_events({"harness_session_id": rest[0], "limit": limit})
    if command in {"help", "-h", "--help"}:
        return _help_text()
    return json.dumps({"success": False, "error": f"Unknown cursor-harness command: {command}", "help": _help_text()})


def _help_text() -> str:
    return (
        "/cursor-harness doctor\n"
        "/cursor-harness status\n"
        "/cursor-harness models\n"
        "/cursor-harness sdk [status|install|me|models|repositories|list_agents]\n"
        "/cursor-harness latest [project]\n"
        "/cursor-harness events <harness_session_id> [limit]\n"
        "/cursor-harness smoke [quick|real|full] [project]\n"
        "/cursor-harness background [list|local_list|status|conversation|delete] [agent_id]\n"
        "/cursor-harness diagnostics\n"
        "/cursor-harness compatibility [list|run]\n"
        "/cursor-harness config [validate|template]\n"
        "/cursor-harness session [list|export|prune]\n"
        "/cursor-harness profiles\n"
        "/cursor-harness approvals [list|get|decide] [request_id]\n"
        "/cursor-harness proposals [list|inbox|get|accept|reject|done|archive|cancel] [proposal_id]\n"
        "/cursor-harness inbox\n"
        "/cursor-harness provider-route [status|bundle] [hermes_root]"
    )
