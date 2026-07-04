"""Tool handlers registered with Hermes."""

from __future__ import annotations

import json
from typing import Any

from .compatibility import load_compatibility_records, run_and_record_compatibility
from .companion import install_cursor_companion
from .config import load_config, resolve_acp_command, resolve_sdk_command, resolve_stream_command
from .config_validator import validate_config
from .background import client_from_config
from .diagnostics import create_diagnostic_bundle
from .harness import run_turn
from .models import list_cursor_models
from .proposal_queue import (
    append_proposal_resolution_event,
    get_cursor_proposal,
    list_cursor_proposals,
    proposal_inbox,
    resolve_cursor_proposal,
)
from .provider_route import validate_provider_route, write_provider_route_bundle
from .security import apply_security_profile, available_security_profiles, ensure_background_allowed
from .smoke import run_smoke_suite
from .sdk_runner import ensure_sdk_package, sdk_catalog_action, sdk_node_dir, sdk_status
from .store import HarnessStore
from .approval_queue import decide_approval_request, get_approval_request, list_approval_requests


def cursor_harness_run(args: dict[str, Any] | None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    store = HarnessStore(cfg.state_dir)
    try:
        result = run_turn(
            cfg=cfg,
            store=store,
            project=str(args.get("project") or ""),
            prompt=str(args.get("prompt") or ""),
            mode=args.get("mode"),
            model=args.get("model"),
            harness_session_id=args.get("harness_session_id"),
            new_session=bool(args.get("new_session", False)),
            transport=args.get("transport"),
            timeout_sec=float(args["timeout_sec"]) if args.get("timeout_sec") else None,
        )
        result["events"] = _tail_events(result.get("events") or [], cfg.max_events_per_result)
        return _format({"success": True, **result}, args=args, kwargs=kwargs)
    except Exception as exc:
        return _format({"success": False, "error": str(exc)}, args=args, kwargs=kwargs)


def cursor_harness_status(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    store = HarnessStore(cfg.state_dir)
    return _format(
        {"success": True, "sessions": store.list_sessions(), "state_dir": str(cfg.state_dir)},
        args=args,
        kwargs=kwargs,
    )


def cursor_harness_events(args: dict[str, Any] | None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    store = HarnessStore(cfg.state_dir)
    limit_raw = args.get("limit")
    limit = int(limit_raw) if limit_raw is not None else cfg.max_events_per_result
    events = store.read_events(str(args.get("harness_session_id") or ""), None if limit < 0 else limit)
    return _format({"success": True, "events": events}, args=args, kwargs=kwargs)


def cursor_harness_latest(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    store = HarnessStore(cfg.state_dir)
    sessions = store.list_sessions()
    project = str(args.get("project") or "")
    if project:
        try:
            project_path = str(cfg.resolve_project(project))
        except Exception:
            project_path = project
        sessions = [item for item in sessions if item.get("project_path") == project_path]
    latest = sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[:1]
    return _format({"success": True, "latest_session": latest[0] if latest else None}, args=args, kwargs=kwargs)


def cursor_harness_models(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    return _format(list_cursor_models(cfg), args=args, kwargs=kwargs)


def cursor_harness_sdk(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    action = str(args.get("action") or "status").lower()
    timeout_sec = float(args["timeout_sec"]) if args.get("timeout_sec") else 45.0
    try:
        if action == "install":
            node_modules = ensure_sdk_package(cfg)
            result = {"success": True, "node_modules": str(node_modules), "sdk_node_dir": str(sdk_node_dir(cfg))}
        elif action == "status":
            result = sdk_status(cfg, timeout_sec=timeout_sec)
            result["sdk_node_dir"] = str(sdk_node_dir(cfg))
        elif action in {"me", "models", "repositories", "list_agents"}:
            result = sdk_catalog_action(cfg, action, timeout_sec=timeout_sec, install=True)
        else:
            result = {"success": False, "error": "action must be status, install, me, models, repositories, or list_agents"}
    except Exception as exc:
        result = {"success": False, "error": str(exc)}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_install_companion(args: dict[str, Any] | None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    project_path = cfg.resolve_project(str(args.get("project") or ""))
    result = install_cursor_companion(
        cfg=cfg,
        project_path=project_path,
        force=bool(args.get("force", False)),
    )
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_smoke(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    store = HarnessStore(cfg.state_dir)
    result = run_smoke_suite(
        cfg=cfg,
        store=store,
        project=args.get("project"),
        level=str(args.get("level") or "quick"),
        timeout_sec=float(args["timeout_sec"]) if args.get("timeout_sec") else None,
        include_cursor_mcp=bool(args.get("include_cursor_mcp", False)),
        include_sdk=bool(args.get("include_sdk", False)),
        include_edit=bool(args.get("include_edit", False)),
        include_concurrency=bool(args.get("include_concurrency", False)),
    )
    return _format(result, args=args, kwargs=kwargs)


_REMOTE_MUTATING_BACKGROUND_ACTIONS = {"launch", "launch_from_latest", "followup", "delete"}


def cursor_harness_background_agent(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    store = HarnessStore(cfg.state_dir)
    try:
        action = str(args.get("action") or "list").lower()
        if action == "local_list":
            return _format({"success": True, "action": action, "result": store.list_background_agents()}, args=args, kwargs=kwargs)
        confirmation_error = _background_confirmation_error(args, action)
        if confirmation_error:
            return _format({"success": False, "error": confirmation_error}, args=args, kwargs=kwargs)
        ensure_background_allowed(cfg)
        client = client_from_config(
            cfg,
            api_key=args.get("api_key"),
            timeout_sec=float(args["timeout_sec"]) if args.get("timeout_sec") else 30.0,
        )
        if action == "launch":
            result = client.launch_agent(
                prompt=str(args.get("prompt") or ""),
                repository=str(args.get("repository") or ""),
                ref=args.get("ref"),
                model=args.get("model"),
                branch_name=args.get("branch_name"),
                auto_create_pr=bool(args.get("auto_create_pr", False)),
                webhook_url=args.get("webhook_url"),
                webhook_secret=args.get("webhook_secret"),
                images=args.get("images"),
            )
            store.record_background_agent({"id": _background_id(result), "action": action, "result": result})
        elif action == "launch_from_latest":
            result = _launch_background_from_latest(client=client, store=store, args=args)
            store.record_background_agent({"id": _background_id(result), "action": action, "result": result})
        elif action == "list":
            result = client.list_agents(limit=int(args.get("limit") or 20), cursor=args.get("cursor"))
        elif action == "status":
            result = client.get_agent(str(args.get("agent_id") or ""))
        elif action == "conversation":
            result = client.get_conversation(str(args.get("agent_id") or ""))
        elif action == "followup":
            result = client.add_followup(
                agent_id=str(args.get("agent_id") or ""),
                prompt=str(args.get("prompt") or ""),
                images=args.get("images"),
            )
        elif action == "sync_result":
            agent_id = str(args.get("agent_id") or "")
            status = client.get_agent(agent_id)
            conversation = client.get_conversation(agent_id)
            result = {"status": status, "conversation": conversation}
            store.record_background_agent({"id": agent_id, "action": action, "result": result})
        elif action == "delete":
            result = client.delete_agent(str(args.get("agent_id") or ""))
        else:
            raise ValueError(
                "action must be launch, launch_from_latest, list, local_list, status, conversation, followup, sync_result, or delete"
            )
        return _format({"success": True, "action": action, "result": result}, args=args, kwargs=kwargs)
    except Exception as exc:
        return _format({"success": False, "error": str(exc)}, args=args, kwargs=kwargs)


def cursor_harness_provider_route(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    action = str(args.get("action") or "status").lower()
    hermes_root = args.get("hermes_root") or args.get("path")
    if action == "status":
        if not hermes_root:
            result = {"success": False, "error": "hermes_root is required for provider route status"}
        else:
            result = validate_provider_route(str(hermes_root))
    elif action in {"bundle", "install_plan"}:
        cfg = load_config()
        output_dir = args.get("output_dir") or (cfg.state_dir / "provider-route-bundle")
        result = write_provider_route_bundle(hermes_root=hermes_root, output_dir=output_dir)
    else:
        result = {"success": False, "error": "action must be status or bundle"}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_diagnostics(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    store = HarnessStore(cfg.state_dir)
    result = create_diagnostic_bundle(
        cfg=cfg,
        store=store,
        output_dir=args.get("output_dir"),
        hermes_root=args.get("hermes_root"),
        include_events=bool(args.get("include_events", True)),
    )
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_compatibility(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    store = HarnessStore(cfg.state_dir)
    action = str(args.get("action") or "list").lower()
    if action == "run":
        result = run_and_record_compatibility(
            cfg=cfg,
            store=store,
            project=args.get("project"),
            level=str(args.get("level") or "quick"),
            timeout_sec=float(args["timeout_sec"]) if args.get("timeout_sec") else None,
            include_cursor_mcp=bool(args.get("include_cursor_mcp", False)),
            include_sdk=bool(args.get("include_sdk", False)),
            include_edit=bool(args.get("include_edit", False)),
            include_concurrency=bool(args.get("include_concurrency", False)),
        )
    elif action == "list":
        result = {"success": True, "records": load_compatibility_records(cfg)}
    else:
        result = {"success": False, "error": "action must be run or list"}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_config(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    action = str(args.get("action") or "validate").lower()
    if action == "validate":
        result = validate_config(
            args.get("path"),
            security_profile=args.get("security_profile"),
            project=args.get("project"),
            include_sdk_status=bool(args.get("include_sdk_status", True)),
        )
    elif action == "template":
        from .cli import _config_template

        result = {"success": True, "template": _config_template()}
    else:
        result = {"success": False, "error": "action must be validate or template"}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_session(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    store = HarnessStore(cfg.state_dir)
    action = str(args.get("action") or "list").lower()
    if action == "list":
        result = {"success": True, "sessions": store.list_sessions()}
    elif action == "name":
        record = store.update_session(str(args.get("harness_session_id") or ""), name=str(args.get("name") or ""))
        result = {"success": True, "session": record.__dict__}
    elif action == "tag":
        tags = args.get("tags") or []
        if isinstance(tags, str):
            tags = [item.strip() for item in tags.split(",")]
        record = store.update_session(str(args.get("harness_session_id") or ""), tags=tags)
        result = {"success": True, "session": record.__dict__}
    elif action == "archive":
        record = store.update_session(str(args.get("harness_session_id") or ""), archived=True)
        result = {"success": True, "session": record.__dict__}
    elif action == "unarchive":
        record = store.update_session(str(args.get("harness_session_id") or ""), archived=False)
        result = {"success": True, "session": record.__dict__}
    elif action == "export":
        result = store.export_session(str(args.get("harness_session_id") or ""), output_dir=args.get("output_dir"))
    elif action == "prune":
        result = store.prune_sessions(
            keep_last=int(args.get("keep_last") or 50),
            include_archived=bool(args.get("include_archived", True)),
            dry_run=bool(args.get("dry_run", False)),
        )
    elif action == "open":
        record = store.get(str(args.get("harness_session_id") or ""))
        result = {
            "success": bool(record),
            "session": record.__dict__ if record else None,
            "resume_command": f"agent --resume {record.cursor_session_id}" if record and record.cursor_session_id else None,
            "sdk_resume": {
                "agent_id": record.cursor_session_id,
                "last_run_id": record.last_sdk_run_id,
                "runtime": "cloud" if (record.cursor_session_id or "").startswith("bc-") else "local",
            }
            if record and record.transport == "sdk" and record.cursor_session_id
            else None,
        }
    else:
        result = {"success": False, "error": "action must be list, name, tag, archive, unarchive, export, prune, or open"}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_security_profiles(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    return _format(
        {"success": True, "active": cfg.security_profile, "profiles": available_security_profiles(cfg)},
        args=args,
        kwargs=kwargs,
    )


def cursor_harness_approvals(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    action = str(args.get("action") or "list").lower()
    try:
        if action == "list":
            result = {
                "success": True,
                "approvals": list_approval_requests(cfg, include_resolved=bool(args.get("include_resolved", False))),
            }
        elif action == "get":
            item = get_approval_request(cfg, str(args.get("request_id") or ""))
            result = {"success": bool(item), "approval": item}
        elif action == "decide":
            result = {
                "success": True,
                "approval": decide_approval_request(
                    cfg,
                    str(args.get("request_id") or ""),
                    option_id=args.get("option_id") or args.get("optionId"),
                    outcome=args.get("outcome"),
                    reason=args.get("reason"),
                ),
            }
        else:
            result = {"success": False, "error": "action must be list, get, or decide"}
    except Exception as exc:
        result = {"success": False, "error": str(exc)}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_proposals(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    action = str(args.get("action") or "list").lower()
    try:
        if action == "list":
            result = {
                "success": True,
                "proposals": list_cursor_proposals(cfg, include_resolved=bool(args.get("include_resolved", False))),
            }
        elif action == "inbox":
            result = proposal_inbox(
                cfg,
                store=HarnessStore(cfg.state_dir),
                include_resolved=bool(args.get("include_resolved", False)),
                limit=int(args.get("limit") or 50),
            )
        elif action == "get":
            item = get_cursor_proposal(cfg, str(args.get("proposal_id") or args.get("id") or ""))
            result = {"success": bool(item), "proposal": item}
        elif action in {"resolve", "accept", "reject", "done", "archive", "cancel"}:
            status = str(args.get("status") or "").lower()
            if not status:
                status = {
                    "accept": "accepted",
                    "reject": "rejected",
                    "done": "done",
                    "archive": "archived",
                    "cancel": "cancelled",
                }.get(action, "")
            item = resolve_cursor_proposal(
                cfg,
                str(args.get("proposal_id") or args.get("id") or ""),
                status=status,
                reason=args.get("reason"),
                resolution=args.get("resolution") if isinstance(args.get("resolution"), dict) else None,
            )
            result = {
                "success": True,
                "proposal": item,
                "resolution_event": append_proposal_resolution_event(cfg, item, source="hermes_tool"),
            }
        else:
            result = {
                "success": False,
                "error": "action must be list, inbox, get, resolve, accept, reject, done, archive, or cancel",
            }
    except Exception as exc:
        result = {"success": False, "error": str(exc)}
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_proposal_inbox(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = load_config()
    result = proposal_inbox(
        cfg,
        store=HarnessStore(cfg.state_dir),
        include_resolved=bool(args.get("include_resolved", False)),
        limit=int(args.get("limit") or 50),
    )
    return _format(result, args=args, kwargs=kwargs)


def cursor_harness_doctor(args: dict[str, Any] | None = None, **kwargs: Any) -> str | dict[str, Any]:
    args = args or {}
    cfg = apply_security_profile(load_config(), args.get("security_profile"))
    result: dict[str, Any] = {
        "success": True,
        "transport": cfg.transport,
        "sdk_runtime": cfg.sdk_runtime,
        "sdk_auto_install": cfg.sdk_auto_install,
        "sdk_package": cfg.sdk_package,
        "sdk_node_dir": str(sdk_node_dir(cfg)),
        "state_dir": str(cfg.state_dir),
        "projects": cfg.projects,
        "trusted_readonly_mcp_tools": cfg.trusted_readonly_mcp_tools,
        "background_api_base_url": cfg.background_api_base_url,
        "security_profile": cfg.security_profile,
        "allow_background_agents": cfg.allow_background_agents,
        "approval_bridge_available": bool(cfg.approval_bridge_command),
        "approval_bridge_command": cfg.approval_bridge_command,
    }
    try:
        result["sdk_command"] = resolve_sdk_command(cfg)
        result["sdk_available"] = True
        status = sdk_status(cfg, timeout_sec=20)
        result["sdk_status"] = {key: value for key, value in status.items() if key not in {"rows", "stderr"}}
        result["sdk_available"] = bool(status.get("success"))
    except Exception as exc:
        result["sdk_available"] = False
        result["sdk_error"] = str(exc)
    try:
        result["acp_command"] = resolve_acp_command(cfg)
        result["acp_available"] = True
    except Exception as exc:
        result["acp_available"] = False
        result["acp_error"] = str(exc)
    try:
        result["stream_command"] = resolve_stream_command(cfg)
        result["stream_available"] = True
    except Exception as exc:
        result["stream_available"] = False
        result["stream_error"] = str(exc)
    result["success"] = bool(result.get("sdk_available") or result.get("acp_available") or result.get("stream_available"))
    return _format(result, args=args, kwargs=kwargs)


def _tail_events(events: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    if limit < 0:
        return events
    return events[-limit:]


def _format(
    data: dict[str, Any],
    *,
    args: dict[str, Any] | None = None,
    kwargs: dict[str, Any] | None = None,
) -> str | dict[str, Any]:
    if _wants_dict(args=args, kwargs=kwargs):
        return data
    return _json(data)


def _wants_dict(*, args: dict[str, Any] | None = None, kwargs: dict[str, Any] | None = None) -> bool:
    return bool((args or {}).get("as_dict") or (kwargs or {}).get("as_dict"))


def _json(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)


def _background_id(result: dict[str, Any]) -> str | None:
    return result.get("id") or result.get("agent_id") or result.get("agentId")


def _background_confirmation_error(args: dict[str, Any], action: str) -> str | None:
    if action not in _REMOTE_MUTATING_BACKGROUND_ACTIONS:
        return None
    if _truthy_arg(args, "confirm_remote", "confirm", "yes"):
        return None
    if action == "delete" and _truthy_arg(args, "confirm_delete"):
        return None
    if action in {"launch", "launch_from_latest"} and _truthy_arg(args, "confirm_launch"):
        return None
    if action == "followup" and _truthy_arg(args, "confirm_followup"):
        return None
    if action == "delete":
        return "remote Background Agents delete requires confirm_delete=true or confirm_remote=true"
    return f"remote Background Agents {action} requires confirm_remote=true"


def _truthy_arg(args: dict[str, Any], *keys: str) -> bool:
    for key in keys:
        value = args.get(key)
        if isinstance(value, bool):
            if value:
                return True
            continue
        if isinstance(value, str) and value.strip().lower() in {"1", "true", "yes", "y", "on"}:
            return True
    return False


def _launch_background_from_latest(*, client: Any, store: HarnessStore, args: dict[str, Any]) -> dict[str, Any]:
    sessions = store.list_sessions()
    if not sessions:
        raise ValueError("no harness sessions available")
    latest = sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[0]
    prompt = str(args.get("prompt") or "").strip()
    context = latest.get("last_result") or ""
    merged_prompt = (
        f"{prompt}\n\n"
        "Hermes Cursor Harness latest-session context:\n"
        f"- harness_session_id: {latest.get('harness_session_id')}\n"
        f"- cursor_session_id: {latest.get('cursor_session_id')}\n"
        f"- mode: {latest.get('mode')}\n"
        f"- last_result: {context}"
    ).strip()
    return client.launch_agent(
        prompt=merged_prompt,
        repository=str(args.get("repository") or ""),
        ref=args.get("ref"),
        model=args.get("model"),
        branch_name=args.get("branch_name"),
        auto_create_pr=bool(args.get("auto_create_pr", False)),
        webhook_url=args.get("webhook_url"),
        webhook_secret=args.get("webhook_secret"),
        images=args.get("images"),
    )
