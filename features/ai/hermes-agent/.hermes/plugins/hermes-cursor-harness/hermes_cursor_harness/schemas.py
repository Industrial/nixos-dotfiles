"""Hermes tool schemas for the Cursor harness."""

RUN_SCHEMA = {
    "name": "cursor_harness_run",
    "description": (
        "Run a Cursor-powered coding-agent turn from Hermes. Uses Cursor SDK first, "
        "falling back to Cursor ACP and Cursor Agent stream-json when configured for auto transport. "
        "Returns live event history, Cursor session IDs, changed-file hints, and final text."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "project": {
                "type": "string",
                "description": "Project alias from ~/.hermes/cursor_harness.json or an absolute project path.",
            },
            "prompt": {"type": "string", "description": "Task for Cursor Agent."},
            "mode": {
                "type": "string",
                "enum": ["plan", "ask", "edit", "full_access", "reject"],
                "description": "Permission mode. Default is safe plan mode unless config overrides it.",
            },
            "model": {"type": "string", "description": "Optional Cursor model hint, when supported."},
            "harness_session_id": {
                "type": "string",
                "description": "Existing Hermes harness session to resume.",
            },
            "new_session": {"type": "boolean", "description": "Force a fresh Cursor session."},
            "transport": {
                "type": "string",
                "enum": ["auto", "sdk", "acp", "stream"],
                "description": "Transport override. auto tries Cursor SDK, ACP, then stream-json.",
            },
            "timeout_sec": {"type": "number", "description": "Turn timeout in seconds."},
            "security_profile": {"type": "string", "description": "Optional security profile override."},
        },
        "required": ["project", "prompt"],
    },
}

STATUS_SCHEMA = {
    "name": "cursor_harness_status",
    "description": "List Hermes Cursor harness sessions and their Cursor session mappings.",
    "parameters": {"type": "object", "properties": {}},
}

EVENTS_SCHEMA = {
    "name": "cursor_harness_events",
    "description": "Read stored Cursor harness events for a session.",
    "parameters": {
        "type": "object",
        "properties": {
            "harness_session_id": {"type": "string", "description": "Harness session ID."},
            "limit": {"type": "integer", "description": "Tail event count. Omit or pass -1 for all events."},
        },
        "required": ["harness_session_id"],
    },
}

DOCTOR_SCHEMA = {
    "name": "cursor_harness_doctor",
    "description": "Check Cursor harness configuration and local Cursor command discovery.",
    "parameters": {"type": "object", "properties": {}},
}

MODELS_SCHEMA = {
    "name": "cursor_harness_models",
    "description": "List models available to the authenticated Cursor Agent account.",
    "parameters": {"type": "object", "properties": {}},
}

SDK_SCHEMA = {
    "name": "cursor_harness_sdk",
    "description": "Install, check, and query Cursor's official @cursor/sdk bridge used by the harness.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["status", "install", "me", "models", "repositories", "list_agents"]},
            "timeout_sec": {"type": "number", "description": "SDK action timeout in seconds."},
        },
    },
}

LATEST_SCHEMA = {
    "name": "cursor_harness_latest",
    "description": "Return the latest Cursor harness session, optionally scoped to a project.",
    "parameters": {
        "type": "object",
        "properties": {
            "project": {
                "type": "string",
                "description": "Optional project alias or absolute path.",
            }
        },
    },
}

INSTALL_COMPANION_SCHEMA = {
    "name": "cursor_harness_install_companion",
    "description": (
        "Install Cursor-side companion files into a project: .cursor/mcp.json, "
        "rules, skills, and plugin skeleton for Cursor-to-Hermes context access."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "project": {
                "type": "string",
                "description": "Project alias from ~/.hermes/cursor_harness.json or absolute path.",
            },
            "force": {
                "type": "boolean",
                "description": "Overwrite existing companion files where applicable.",
            },
        },
        "required": ["project"],
    },
}

SMOKE_SCHEMA = {
    "name": "cursor_harness_smoke",
    "description": (
        "Run a bounded self-test suite for the Hermes Cursor Harness. quick checks local config; "
        "real adds live Cursor ACP/stream runs; full also asks Cursor to call the Hermes MCP backchannel."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "project": {"type": "string", "description": "Project alias or absolute path for real/full smokes."},
            "level": {"type": "string", "enum": ["quick", "real", "full"], "description": "Smoke depth."},
            "timeout_sec": {"type": "number", "description": "Timeout for each live Cursor turn."},
            "include_cursor_mcp": {"type": "boolean", "description": "Ask Cursor Agent itself to call the MCP backchannel."},
            "include_sdk": {"type": "boolean", "description": "Run a live Cursor SDK transport check in the real/full smoke."},
            "include_edit": {"type": "boolean", "description": "Run a sacrificial temp-repo edit smoke."},
            "include_concurrency": {"type": "boolean", "description": "Run two live sessions and verify isolation."},
            "security_profile": {"type": "string", "description": "Optional security profile override."},
        },
    },
}

BACKGROUND_AGENT_SCHEMA = {
    "name": "cursor_harness_background_agent",
    "description": "Create and manage Cursor Background Agents through Cursor's public beta API.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": [
                    "launch",
                    "launch_from_latest",
                    "list",
                    "local_list",
                    "status",
                    "conversation",
                    "followup",
                    "sync_result",
                    "delete",
                ],
                "description": "Background agent operation.",
            },
            "agent_id": {"type": "string", "description": "Background agent ID for status/conversation/followup/delete."},
            "prompt": {"type": "string", "description": "Launch or follow-up prompt."},
            "repository": {"type": "string", "description": "GitHub repository URL for launch."},
            "ref": {"type": "string", "description": "Git ref for launch."},
            "model": {"type": "string", "description": "Cursor background agent model hint."},
            "branch_name": {"type": "string", "description": "Target branch name for launch."},
            "auto_create_pr": {"type": "boolean", "description": "Ask Cursor to create a PR when complete."},
            "webhook_url": {"type": "string", "description": "Optional webhook URL."},
            "webhook_secret": {"type": "string", "description": "Optional webhook secret."},
            "limit": {"type": "integer", "description": "List page size."},
            "cursor": {"type": "string", "description": "List pagination cursor."},
            "api_key": {"type": "string", "description": "Optional API key override; otherwise use CURSOR_BACKGROUND_API_KEY or CURSOR_API_KEY."},
            "timeout_sec": {"type": "number", "description": "HTTP request timeout."},
            "security_profile": {"type": "string", "description": "Optional security profile override."},
        },
    },
}

PROVIDER_ROUTE_SCHEMA = {
    "name": "cursor_harness_provider_route",
    "description": "Validate or bundle the Hermes core provider-route integration needed for native cursor/* models.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["status", "bundle", "install_plan"]},
            "hermes_root": {"type": "string", "description": "Path to a Hermes checkout."},
            "output_dir": {"type": "string", "description": "Where to write a provider-route bundle."},
        },
    },
}

DIAGNOSTICS_SCHEMA = {
    "name": "cursor_harness_diagnostics",
    "description": "Write a redacted diagnostic zip with config, sessions, events, versions, and optional provider-route status.",
    "parameters": {
        "type": "object",
        "properties": {
            "output_dir": {"type": "string"},
            "hermes_root": {"type": "string"},
            "include_events": {"type": "boolean"},
            "security_profile": {"type": "string"},
        },
    },
}

COMPATIBILITY_SCHEMA = {
    "name": "cursor_harness_compatibility",
    "description": "Run or list compatibility matrix records for Cursor CLI/Hermes harness combinations.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["run", "list"]},
            "project": {"type": "string"},
            "level": {"type": "string", "enum": ["quick", "real", "full"]},
            "timeout_sec": {"type": "number"},
            "security_profile": {"type": "string"},
            "include_cursor_mcp": {"type": "boolean"},
            "include_sdk": {"type": "boolean"},
            "include_edit": {"type": "boolean"},
            "include_concurrency": {"type": "boolean"},
        },
    },
}

CONFIG_SCHEMA = {
    "name": "cursor_harness_config",
    "description": "Validate or print Hermes Cursor Harness configuration with structured checks.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["validate", "template"]},
            "path": {"type": "string", "description": "Optional config path override."},
            "project": {"type": "string", "description": "Optional project alias/path to validate."},
            "security_profile": {"type": "string", "description": "Optional security profile to apply while validating."},
            "include_sdk_status": {"type": "boolean", "description": "Run the local SDK bridge status check."},
        },
    },
}

SESSION_SCHEMA = {
    "name": "cursor_harness_session",
    "description": "Name, tag, archive, export, prune, or inspect Cursor harness sessions.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["list", "name", "tag", "archive", "unarchive", "export", "prune", "open"]},
            "harness_session_id": {"type": "string"},
            "name": {"type": "string"},
            "tags": {
                "anyOf": [
                    {"type": "array", "items": {"type": "string"}},
                    {"type": "string"},
                ]
            },
            "output_dir": {"type": "string"},
            "keep_last": {"type": "integer"},
            "include_archived": {"type": "boolean"},
            "dry_run": {"type": "boolean"},
        },
    },
}

SECURITY_PROFILES_SCHEMA = {
    "name": "cursor_harness_security_profiles",
    "description": "List built-in and configured Hermes Cursor Harness security profiles.",
    "parameters": {"type": "object", "properties": {}},
}

APPROVALS_SCHEMA = {
    "name": "cursor_harness_approvals",
    "description": "List or decide pending Cursor ACP approval requests for a Hermes UI approval bridge.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["list", "get", "decide"]},
            "request_id": {"type": "string"},
            "option_id": {"type": "string"},
            "optionId": {"type": "string"},
            "outcome": {"type": "string", "enum": ["reject", "cancelled", "expired"]},
            "reason": {"type": "string"},
            "include_resolved": {"type": "boolean"},
        },
    },
}

PROPOSALS_SCHEMA = {
    "name": "cursor_harness_proposals",
    "description": "List, inspect, or resolve reviewable Cursor-to-Hermes proposals created through the Cursor MCP backchannel.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["list", "inbox", "get", "resolve", "accept", "reject", "done", "archive", "cancel"],
            },
            "proposal_id": {"type": "string"},
            "id": {"type": "string"},
            "status": {"type": "string", "enum": ["accepted", "rejected", "done", "archived", "cancelled"]},
            "reason": {"type": "string"},
            "resolution": {"type": "object"},
            "include_resolved": {"type": "boolean"},
            "limit": {"type": "integer"},
        },
    },
}

PROPOSAL_INBOX_SCHEMA = {
    "name": "cursor_harness_proposal_inbox",
    "description": "Return a Hermes UI-friendly inbox of Cursor-to-Hermes proposals with linked session events.",
    "parameters": {
        "type": "object",
        "properties": {
            "include_resolved": {"type": "boolean"},
            "limit": {"type": "integer"},
        },
    },
}
