"""Command-line helpers for local harness maintenance."""

from __future__ import annotations

import argparse
import getpass
import json
import shutil
import sys
from pathlib import Path
from typing import Any

from .approval_queue import approval_bridge_stdio, decide_approval_request, get_approval_request, list_approval_requests
from .compatibility import load_compatibility_records, run_and_record_compatibility
from .config import DEFAULT_TRUSTED_READONLY_MCP_TOOLS, default_config_path, default_hermes_home, load_config
from .config_validator import validate_config
from .credentials import (
    CredentialError,
    background_key_status,
    delete_background_key_from_keychain,
    redact_secret,
    store_background_key_in_keychain,
)
from .diagnostics import create_diagnostic_bundle
from .proposal_queue import (
    append_proposal_resolution_event,
    get_cursor_proposal,
    list_cursor_proposals,
    proposal_inbox,
    proposal_inbox_text,
    resolve_cursor_proposal,
)
from .provider_route import validate_provider_route, write_provider_route_bundle
from .security import available_security_profiles, apply_security_profile
from .sdk_runner import ensure_sdk_package, sdk_catalog_action, sdk_node_dir, sdk_status
from .smoke import run_smoke_suite, summary_text
from .store import HarnessStore
from .tools import cursor_harness_background_agent, cursor_harness_doctor


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="hermes-cursor-harness")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("doctor", help="Check local Cursor/Hermes harness configuration")

    smoke = sub.add_parser("smoke", help="Run harness self-tests")
    smoke.add_argument("--project", default="")
    smoke.add_argument("--level", choices=["quick", "real", "full"], default="quick")
    smoke.add_argument("--timeout-sec", type=float, default=None)
    smoke.add_argument("--include-cursor-mcp", action="store_true")
    smoke.add_argument("--include-sdk", action="store_true")
    smoke.add_argument("--include-edit", action="store_true")
    smoke.add_argument("--include-concurrency", action="store_true")
    smoke.add_argument("--security-profile", default="")
    smoke.add_argument("--json", action="store_true")

    sub.add_parser("config-template", help="Print an example cursor_harness.json")

    config = sub.add_parser("config", help="Validate or print harness configuration")
    config.add_argument("action", choices=["validate", "template"], nargs="?", default="validate")
    config.add_argument("--path", default="")
    config.add_argument("--project", default="")
    config.add_argument("--security-profile", default="")
    config.add_argument("--no-sdk-status", action="store_true")

    profiles = sub.add_parser("profiles", help="List security profiles")
    profiles.add_argument("--json", action="store_true")

    approval_bridge = sub.add_parser("approval-bridge", help="Run the stdio approval bridge used by Hermes UI integrations")
    approval_bridge.add_argument("--timeout-sec", type=float, default=None)

    approvals = sub.add_parser("approvals", help="List, inspect, or decide pending approval bridge requests")
    approvals.add_argument("action", choices=["list", "get", "decide"], nargs="?", default="list")
    approvals.add_argument("request_id", nargs="?")
    approvals.add_argument("--include-resolved", action="store_true")
    approvals.add_argument("--option-id", default="")
    approvals.add_argument("--outcome", choices=["reject", "cancelled", "expired"], default="")
    approvals.add_argument("--reason", default="")

    proposals = sub.add_parser("proposals", help="List, inspect, or resolve Cursor-to-Hermes proposals")
    proposals.add_argument("action", choices=["list", "inbox", "get", "resolve", "accept", "reject", "done", "archive", "cancel"], nargs="?", default="list")
    proposals.add_argument("proposal_id", nargs="?")
    proposals.add_argument("--include-resolved", action="store_true")
    proposals.add_argument("--limit", type=int, default=50)
    proposals.add_argument("--format", choices=["json", "text"], default="json", help="Output format for the inbox action")
    proposals.add_argument("--status", choices=["accepted", "rejected", "done", "archived", "cancelled"], default="")
    proposals.add_argument("--reason", default="")

    inbox = sub.add_parser("inbox", help="Show Hermes UI-friendly Cursor proposal inbox")
    inbox.add_argument("--include-resolved", action="store_true")
    inbox.add_argument("--limit", type=int, default=50)
    inbox.add_argument("--format", choices=["json", "text"], default="json")

    background = sub.add_parser("background", help="Run a live Cursor Background Agents API operation")
    background.add_argument(
        "action",
        choices=[
            "list",
            "local_list",
            "status",
            "conversation",
            "delete",
            "launch",
            "launch_from_latest",
            "followup",
            "sync_result",
        ],
        nargs="?",
        default="list",
    )
    background.add_argument("--agent-id", default="")
    background.add_argument("--repository", default="")
    background.add_argument("--ref", default="")
    background.add_argument("--prompt", default="")
    background.add_argument("--model", default="")
    background.add_argument("--branch-name", default="")
    background.add_argument("--auto-create-pr", action="store_true")
    background.add_argument("--limit", type=int, default=20)
    background.add_argument("--cursor", default="")
    background.add_argument("--api-key", default="")
    background.add_argument("--timeout-sec", type=float, default=30.0)
    background.add_argument("--security-profile", default="")
    background.add_argument("--confirm-remote", action="store_true", help="Confirm launch, follow-up, or delete against Cursor Background Agents")
    background.add_argument("--yes", action="store_true", help="Alias for --confirm-remote in non-interactive scripts")

    background_key = sub.add_parser("background-key", help="Store, inspect, or test the Cursor Background Agents API key")
    background_key.add_argument("action", choices=["status", "set", "delete", "test"], nargs="?", default="status")
    background_key.add_argument("--stdin", action="store_true", help="Read the key from stdin for set")
    background_key.add_argument("--value", default="", help="API key value for set; prefer --stdin or prompt to avoid shell history")
    background_key.add_argument("--account", default="", help="macOS Keychain account override")
    background_key.add_argument("--timeout-sec", type=float, default=20.0)

    api_key = sub.add_parser("api-key", help="Store, inspect, or test the Cursor API key used by SDK and Background Agents")
    api_key.add_argument("action", choices=["status", "set", "delete", "test"], nargs="?", default="status")
    api_key.add_argument("--stdin", action="store_true", help="Read the key from stdin for set")
    api_key.add_argument("--value", default="", help="API key value for set; prefer --stdin or prompt to avoid shell history")
    api_key.add_argument("--account", default="", help="macOS Keychain account override")
    api_key.add_argument("--timeout-sec", type=float, default=20.0)

    sdk = sub.add_parser("sdk", help="Install, check, or query the official Cursor SDK bridge")
    sdk.add_argument("action", choices=["status", "install", "me", "models", "repositories", "list_agents"], nargs="?", default="status")
    sdk.add_argument("--timeout-sec", type=float, default=45.0)

    diag = sub.add_parser("diagnostics", help="Create a redacted diagnostic bundle")
    diag.add_argument("--output-dir", default="")
    diag.add_argument("--hermes-root", default="")
    diag.add_argument("--no-events", action="store_true")

    route = sub.add_parser("provider-route", help="Validate or bundle the Hermes core provider route")
    route.add_argument("action", choices=["status", "bundle"], nargs="?", default="status")
    route.add_argument("--hermes-root", default="")
    route.add_argument("--output-dir", default="")

    compat = sub.add_parser("compatibility", help="Run or list compatibility matrix records")
    compat.add_argument("action", choices=["list", "run"], nargs="?", default="list")
    compat.add_argument("--project", default="")
    compat.add_argument("--level", choices=["quick", "real", "full"], default="quick")
    compat.add_argument("--timeout-sec", type=float, default=None)
    compat.add_argument("--include-cursor-mcp", action="store_true")
    compat.add_argument("--include-sdk", action="store_true")
    compat.add_argument("--include-edit", action="store_true")
    compat.add_argument("--include-concurrency", action="store_true")

    uninstall = sub.add_parser("uninstall", help="Remove installed plugin files")
    uninstall.add_argument("--yes", action="store_true", help="Actually remove files")

    args = parser.parse_args(argv)
    if args.command == "doctor":
        print(cursor_harness_doctor({}))
        return 0
    if args.command == "smoke":
        cfg = apply_security_profile(load_config(), args.security_profile or None)
        result = run_smoke_suite(
            cfg=cfg,
            store=HarnessStore(cfg.state_dir),
            project=args.project or None,
            level=args.level,
            timeout_sec=args.timeout_sec,
            include_cursor_mcp=args.include_cursor_mcp,
            include_sdk=args.include_sdk,
            include_edit=args.include_edit,
            include_concurrency=args.include_concurrency,
        )
        print(json.dumps(result, indent=2, sort_keys=True) if args.json else summary_text(result))
        return 0 if result.get("success") else 1
    if args.command == "profiles":
        cfg = load_config()
        result = {"active": cfg.security_profile, "profiles": available_security_profiles(cfg)}
        print(json.dumps(result, indent=2, sort_keys=True) if args.json else _profiles_text(result))
        return 0
    if args.command == "approval-bridge":
        result = approval_bridge_stdio(load_config(), timeout_sec=args.timeout_sec)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.command == "approvals":
        cfg = load_config()
        result = _approval_cli_result(cfg=cfg, args=args)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "proposals":
        cfg = load_config()
        result = _proposal_cli_result(cfg=cfg, args=args)
        if args.action == "inbox" and args.format == "text" and result.get("success"):
            print(proposal_inbox_text(result))
        else:
            print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "inbox":
        cfg = load_config()
        result = proposal_inbox(
            cfg,
            store=HarnessStore(cfg.state_dir),
            include_resolved=args.include_resolved,
            limit=args.limit,
        )
        print(proposal_inbox_text(result) if args.format == "text" else json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "config":
        if args.action == "template":
            result = {"success": True, "template": _config_template()}
        else:
            result = validate_config(
                args.path or None,
                project=args.project or None,
                security_profile=args.security_profile or None,
                include_sdk_status=not args.no_sdk_status,
            )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "background":
        result = cursor_harness_background_agent(_background_cli_args(args))
        print(json.dumps(result, indent=2, sort_keys=True) if isinstance(result, dict) else result)
        success = result.get("success") if isinstance(result, dict) else json.loads(result).get("success")
        return 0 if success else 1
    if args.command in {"background-key", "api-key"}:
        result = _background_key_cli_result(args)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "sdk":
        result = _sdk_cli_result(args)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "diagnostics":
        cfg = load_config()
        result = create_diagnostic_bundle(
            cfg=cfg,
            store=HarnessStore(cfg.state_dir),
            output_dir=args.output_dir or None,
            hermes_root=args.hermes_root or None,
            include_events=not args.no_events,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "provider-route":
        if args.action == "status":
            if not args.hermes_root:
                parser.error("provider-route status requires --hermes-root")
            result = validate_provider_route(args.hermes_root)
        else:
            cfg = load_config()
            result = write_provider_route_bundle(
                hermes_root=args.hermes_root or None,
                output_dir=args.output_dir or (cfg.state_dir / "provider-route-bundle"),
            )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "compatibility":
        cfg = load_config()
        store = HarnessStore(cfg.state_dir)
        result = (
            run_and_record_compatibility(
                cfg=cfg,
                store=store,
                project=args.project or None,
                level=args.level,
                timeout_sec=args.timeout_sec,
                include_cursor_mcp=args.include_cursor_mcp,
                include_sdk=args.include_sdk,
                include_edit=args.include_edit,
                include_concurrency=args.include_concurrency,
            )
            if args.action == "run"
            else {"success": True, "records": load_compatibility_records(cfg)}
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("success") else 1
    if args.command == "config-template":
        print(json.dumps(_config_template(), indent=2, sort_keys=True))
        return 0
    if args.command == "uninstall":
        return _uninstall(confirm=args.yes)
    return 2


def _config_template() -> dict[str, Any]:
    return {
        "transport": "auto",
        "projects": {"my-app": "/absolute/path/to/my-app"},
        "sdk_runtime": "local",
        "sdk_package": "@cursor/sdk@latest",
        "sdk_auto_install": True,
        "sdk_setting_sources": ["project", "user", "team", "plugins"],
        "sdk_sandbox_enabled": True,
        "sdk_cloud_repository": "",
        "sdk_cloud_ref": "",
        "sdk_auto_create_pr": False,
        "default_permission_policy": "plan",
        "default_timeout_sec": 900,
        "no_output_timeout_sec": 120,
        "trusted_readonly_mcp_tools": DEFAULT_TRUSTED_READONLY_MCP_TOOLS,
        "background_api_base_url": "https://api.cursor.com",
        "allow_background_agents": True,
        "security_profile": "",
        "security_profiles": {},
        "approval_bridge_command": ["hermes-cursor-harness", "approval-bridge"],
        "approval_bridge_timeout_sec": 120,
        "mcp_servers": [],
    }


def _approval_cli_result(*, cfg, args) -> dict[str, Any]:
    if args.action == "list":
        return {"success": True, "approvals": list_approval_requests(cfg, include_resolved=args.include_resolved)}
    if args.action == "get":
        if not args.request_id:
            return {"success": False, "error": "request_id is required"}
        item = get_approval_request(cfg, args.request_id)
        return {"success": bool(item), "approval": item}
    if not args.request_id:
        return {"success": False, "error": "request_id is required"}
    if not args.option_id and not args.outcome:
        return {"success": False, "error": "--option-id or --outcome is required"}
    try:
        return {
            "success": True,
            "approval": decide_approval_request(
                cfg,
                args.request_id,
                option_id=args.option_id or None,
                outcome=args.outcome or None,
                reason=args.reason or None,
            ),
        }
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def _proposal_cli_result(*, cfg, args) -> dict[str, Any]:
    if args.action == "list":
        return {"success": True, "proposals": list_cursor_proposals(cfg, include_resolved=args.include_resolved)}
    if args.action == "inbox":
        return proposal_inbox(
            cfg,
            store=HarnessStore(cfg.state_dir),
            include_resolved=args.include_resolved,
            limit=args.limit,
        )
    if args.action == "get":
        if not args.proposal_id:
            return {"success": False, "error": "proposal_id is required"}
        try:
            item = get_cursor_proposal(cfg, args.proposal_id)
        except Exception as exc:
            return {"success": False, "error": str(exc)}
        return {"success": bool(item), "proposal": item}
    if not args.proposal_id:
        return {"success": False, "error": "proposal_id is required"}
    status = args.status or {
        "accept": "accepted",
        "reject": "rejected",
        "done": "done",
        "archive": "archived",
        "cancel": "cancelled",
    }.get(args.action, "")
    try:
        return {
            "success": True,
            "proposal": (
                proposal := resolve_cursor_proposal(
                    cfg,
                    args.proposal_id,
                    status=status,
                    reason=args.reason or None,
                )
            ),
            "resolution_event": append_proposal_resolution_event(
                cfg,
                proposal,
                source="hermes_cli",
            ),
        }
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def _background_cli_args(args) -> dict[str, Any]:
    return {
        "as_dict": True,
        "action": args.action,
        "agent_id": args.agent_id,
        "repository": args.repository,
        "ref": args.ref or None,
        "prompt": args.prompt,
        "model": args.model or None,
        "branch_name": args.branch_name or None,
        "auto_create_pr": args.auto_create_pr,
        "limit": args.limit,
        "cursor": args.cursor or None,
        "api_key": args.api_key or None,
        "timeout_sec": args.timeout_sec,
        "security_profile": args.security_profile or None,
        "confirm_remote": bool(args.confirm_remote or args.yes),
        "confirm_delete": bool(args.confirm_remote or args.yes),
    }


def _background_key_cli_result(args) -> dict[str, Any]:
    if args.action == "status":
        status = background_key_status()
        return {"success": True, **status.public()}
    if args.action == "set":
        try:
            key = _read_background_key_from_args(args)
            store_background_key_in_keychain(key, account=args.account or None)
            return {"success": True, "stored": True, "available": True, "source": "macos-keychain", "fingerprint": redact_secret(key)}
        except Exception as exc:
            return {"success": False, "error": str(exc)}
    if args.action == "delete":
        deleted = delete_background_key_from_keychain(account=args.account or None)
        return {"success": True, "deleted": deleted}
    if args.action == "test":
        return _background_key_test(timeout_sec=args.timeout_sec)
    return {"success": False, "error": "action must be status, set, delete, or test"}


def _sdk_cli_result(args) -> dict[str, Any]:
    cfg = load_config()
    try:
        if args.action == "install":
            node_modules = ensure_sdk_package(cfg)
            return {"success": True, "node_modules": str(node_modules), "sdk_node_dir": str(sdk_node_dir(cfg))}
        if args.action == "status":
            result = sdk_status(cfg, timeout_sec=args.timeout_sec)
            result["sdk_node_dir"] = str(sdk_node_dir(cfg))
            return result
        return sdk_catalog_action(cfg, args.action, timeout_sec=args.timeout_sec, install=True)
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def _read_background_key_from_args(args) -> str:
    if args.value:
        return str(args.value).strip()
    if args.stdin:
        return sys.stdin.read().strip()
    return getpass.getpass("Cursor Background Agents API key: ").strip()


def _background_key_test(*, timeout_sec: float) -> dict[str, Any]:
    status = background_key_status(include_key=True)
    if not status.key:
        return {
            "success": False,
            "available": False,
            "source": status.source,
            "error": "Cursor Background Agents API key is not configured",
        }
    try:
        cfg = load_config()
        from .background import BackgroundAgentClient

        info = BackgroundAgentClient(api_key=status.key, base_url=cfg.background_api_base_url, timeout_sec=timeout_sec).api_key_info()
        return {
            "success": True,
            "available": True,
            "source": status.source,
            "fingerprint": status.fingerprint,
            "api_key_info": _redact_key_info(info),
        }
    except CredentialError as exc:
        return {"success": False, "available": False, "source": status.source, "error": str(exc)}
    except Exception as exc:
        return {"success": False, "available": True, "source": status.source, "fingerprint": status.fingerprint, "error": str(exc)}


def _redact_key_info(info: dict[str, Any]) -> dict[str, Any]:
    redacted = dict(info)
    email = redacted.get("userEmail")
    if isinstance(email, str) and "@" in email:
        local, domain = email.split("@", 1)
        redacted["userEmail"] = f"{local[:2]}...@{domain}"
    return redacted


def _profiles_text(result: dict[str, Any]) -> str:
    lines = [f"Active security profile: {result.get('active') or '(none)'}"]
    for name, profile in sorted((result.get("profiles") or {}).items()):
        lines.append(f"- {name}: {profile.get('description', '')}")
    return "\n".join(lines)


def _uninstall(*, confirm: bool) -> int:
    hermes_home = default_hermes_home()
    plugin_dir = hermes_home / "plugins" / "hermes-cursor-harness"
    wrapper = Path.home() / ".local" / "bin" / "hermes-cursor-harness-mcp"
    cli_wrapper = Path.home() / ".local" / "bin" / "hermes-cursor-harness"
    targets = [plugin_dir, wrapper, cli_wrapper]
    if not confirm:
        print("Would remove:")
        for target in targets:
            print(f"- {target}")
        print("Pass --yes to remove these files. Config/state are left in place:")
        print(f"- {default_config_path()}")
        print(f"- {hermes_home / 'cursor_harness'}")
        return 0
    for target in targets:
        if target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()
    print("Removed installed Hermes Cursor Harness plugin and wrappers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
