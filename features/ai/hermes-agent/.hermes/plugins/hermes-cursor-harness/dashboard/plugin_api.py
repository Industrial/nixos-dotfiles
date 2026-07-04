"""Dashboard API for the Hermes Cursor Harness plugin."""

from __future__ import annotations

import sys
import os
from pathlib import Path
from typing import Any

from fastapi import APIRouter
from pydantic import BaseModel

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
if str(PLUGIN_ROOT) not in sys.path:
    sys.path.insert(0, str(PLUGIN_ROOT))

# Match the proven local smoke configuration: Cursor's local SDK sandboxing is
# not available in this desktop test environment, so dashboard-driven local SDK
# runs default to non-sandboxed plan mode unless the operator explicitly opts in.
os.environ.setdefault("HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED", "false")

from hermes_cursor_harness.background import client_from_config
from hermes_cursor_harness.config import load_config
from hermes_cursor_harness.credentials import background_key_status
from hermes_cursor_harness.store import HarnessStore
from hermes_cursor_harness import tools

router = APIRouter()


class DemoRequest(BaseModel):
    project: str | None = None
    prompt: str | None = None
    token: str = "HCH_UI_DEMO_OK"
    transport: str = "sdk"


class BackgroundFromLatestRequest(BaseModel):
    prompt: str | None = None
    repository: str | None = None
    ref: str | None = None
    model: str | None = None
    branch_name: str | None = None
    auto_create_pr: bool = False
    confirm_remote_launch: bool = False


@router.get("/summary")
async def summary() -> dict[str, Any]:
    cfg = load_config()
    store = HarnessStore(cfg.state_dir)
    sessions = store.list_sessions()
    latest = sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[:1]
    doctor = tools.cursor_harness_doctor({"as_dict": True})
    sdk = tools.cursor_harness_sdk({"as_dict": True, "action": "status", "timeout_sec": 20})
    inbox = tools.cursor_harness_proposal_inbox({"as_dict": True, "limit": 5})
    background: dict[str, Any]
    try:
        background = tools.cursor_harness_background_agent({"as_dict": True, "action": "list", "limit": 5, "timeout_sec": 20})
    except Exception as exc:
        background = {"success": False, "error": str(exc)}
    return {
        "success": True,
        "doctor": doctor,
        "sdk": sdk,
        "api_key": background_key_status().public(),
        "background": background,
        "latest_session": latest[0] if latest else None,
        "session_count": len(sessions),
        "proposal_inbox": inbox,
    }


@router.get("/models")
async def models() -> dict[str, Any]:
    result = tools.cursor_harness_sdk({"as_dict": True, "action": "models", "timeout_sec": 45})
    rows = result.get("result") or []
    if not isinstance(rows, list):
        rows = []
    return {
        "success": bool(result.get("success")),
        "count": len(rows),
        "sample": [
            {"id": item.get("id"), "displayName": item.get("displayName")}
            for item in rows[:12]
            if isinstance(item, dict)
        ],
        "error": result.get("error"),
    }


@router.post("/demo")
async def demo(body: DemoRequest) -> dict[str, Any]:
    cfg = load_config()
    project = body.project or next(iter(cfg.projects.values()), str(PLUGIN_ROOT))
    token = body.token or "HCH_UI_DEMO_OK"
    prompt = body.prompt or (
        "Do not edit files. Reply with exactly one short paragraph that "
        f"includes {token} and says this answer came through the Hermes "
        "Cursor Harness dashboard using Cursor SDK."
    )
    result = tools.cursor_harness_run(
        {
            "as_dict": True,
            "project": project,
            "transport": body.transport or "sdk",
            "mode": "plan",
            "new_session": True,
            "timeout_sec": 180,
            "prompt": prompt,
        }
    )
    return {
        "success": bool(result.get("success")),
        "transport": result.get("transport"),
        "harness_session_id": result.get("harness_session_id"),
        "cursor_session_id": result.get("cursor_session_id"),
        "sdk_run_id": result.get("sdk_run_id"),
        "token": token,
        "token_seen": token in str(result.get("text") or ""),
        "modified_files": result.get("modified_files") or [],
        "text": result.get("text"),
        "error": result.get("error"),
    }


@router.post("/background/from-latest")
async def background_from_latest(body: BackgroundFromLatestRequest) -> dict[str, Any]:
    if not body.confirm_remote_launch:
        return {
            "success": False,
            "error": "Launching a Cursor Background Agent sends prompt/session context to Cursor and requires confirm_remote_launch=true.",
        }
    cfg = load_config()
    client = client_from_config(cfg, timeout_sec=30)
    store = HarnessStore(cfg.state_dir)
    sessions = store.list_sessions()
    if not sessions:
        return {"success": False, "error": "No harness session is available yet."}
    latest = sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[0]
    prompt = str(body.prompt or "").strip()
    if not prompt:
        prompt = "Continue from the latest Hermes Cursor Harness session context."
    merged = (
        f"{prompt}\n\n"
        "Latest Hermes Cursor Harness session:\n"
        f"- harness_session_id: {latest.get('harness_session_id')}\n"
        f"- cursor_session_id: {latest.get('cursor_session_id')}\n"
        f"- transport: {latest.get('transport')}\n"
        f"- last_result: {latest.get('last_result') or ''}"
    )
    result = client.launch_agent(
        prompt=merged,
        repository=str(body.repository or ""),
        ref=body.ref,
        model=body.model,
        branch_name=body.branch_name,
        auto_create_pr=body.auto_create_pr,
    )
    return {"success": True, "result": result}
