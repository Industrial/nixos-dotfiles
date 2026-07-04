"""Security profiles for Hermes Cursor Harness runs."""

from __future__ import annotations

from dataclasses import replace
from typing import Any

from .config import DEFAULT_TRUSTED_READONLY_MCP_TOOLS, WRITEBACK_MCP_TOOLS, HarnessConfig


BUILTIN_SECURITY_PROFILES: dict[str, dict[str, Any]] = {
    "readonly": {
        "description": "Read-only local work. Cursor may inspect repo context and Hermes MCP context, but should not edit.",
        "default_permission_policy": "plan",
        "allowed_transports": ["auto", "sdk", "acp", "stream"],
        "trusted_readonly_mcp_tools": DEFAULT_TRUSTED_READONLY_MCP_TOOLS,
        "allow_background_agents": False,
    },
    "repo-edit": {
        "description": "Focused local repo edits. Cursor may make normal edit-mode changes in configured projects.",
        "default_permission_policy": "edit",
        "allowed_transports": ["auto", "sdk", "acp", "stream"],
        "trusted_readonly_mcp_tools": DEFAULT_TRUSTED_READONLY_MCP_TOOLS,
        "allow_background_agents": False,
    },
    "trusted-local": {
        "description": "Trusted local workspace. Cursor may use broad local approval behavior.",
        "default_permission_policy": "full_access",
        "allowed_transports": ["auto", "sdk", "acp", "stream"],
        "trusted_readonly_mcp_tools": DEFAULT_TRUSTED_READONLY_MCP_TOOLS,
        "allow_background_agents": True,
    },
    "background-safe": {
        "description": "Remote Background Agents are allowed, while local harness turns stay read-only by default.",
        "default_permission_policy": "plan",
        "allowed_transports": ["auto", "sdk", "acp", "stream"],
        "trusted_readonly_mcp_tools": DEFAULT_TRUSTED_READONLY_MCP_TOOLS,
        "allow_background_agents": True,
    },
}


def available_security_profiles(cfg: HarnessConfig) -> dict[str, dict[str, Any]]:
    profiles = {name: dict(value) for name, value in BUILTIN_SECURITY_PROFILES.items()}
    for name, value in (cfg.security_profiles or {}).items():
        if isinstance(value, dict):
            profiles[str(name)] = {**profiles.get(str(name), {}), **value}
    return profiles


def profile_detail(cfg: HarnessConfig, name: str | None = None) -> dict[str, Any] | None:
    selected = (name or cfg.security_profile or "").strip()
    if not selected:
        return None
    return available_security_profiles(cfg).get(selected)


def apply_security_profile(cfg: HarnessConfig, name: str | None = None) -> HarnessConfig:
    selected = (name or cfg.security_profile or "").strip()
    if not selected:
        return cfg
    profile = profile_detail(cfg, selected)
    if profile is None:
        raise ValueError(f"unknown security profile {selected!r}")
    trusted_readonly_mcp_tools = [
        str(item) for item in profile.get("trusted_readonly_mcp_tools", cfg.trusted_readonly_mcp_tools)
    ]
    unsafe_trusted = sorted(set(trusted_readonly_mcp_tools).intersection(WRITEBACK_MCP_TOOLS))
    if unsafe_trusted:
        raise ValueError(
            "security profile trusted_readonly_mcp_tools cannot include writeback tools: "
            + ", ".join(unsafe_trusted)
        )
    return replace(
        cfg,
        security_profile=selected,
        transport=str(profile.get("transport") or cfg.transport),
        default_permission_policy=str(profile.get("default_permission_policy") or cfg.default_permission_policy),
        trusted_readonly_mcp_tools=trusted_readonly_mcp_tools,
        allow_background_agents=_coerce_profile_bool(profile.get("allow_background_agents", cfg.allow_background_agents)),
    )


def ensure_transport_allowed(cfg: HarnessConfig, transport: str) -> None:
    profile = profile_detail(cfg)
    if not profile:
        return
    allowed = profile.get("allowed_transports")
    if not allowed:
        return
    if transport not in set(str(item) for item in allowed):
        raise ValueError(f"transport {transport!r} is not allowed by security profile {cfg.security_profile!r}")


def ensure_background_allowed(cfg: HarnessConfig) -> None:
    if cfg.allow_background_agents is False:
        if cfg.security_profile:
            raise ValueError(f"background agents are not allowed by security profile {cfg.security_profile!r}")
        raise ValueError("background agents are disabled by configuration")


def _coerce_profile_bool(raw: Any) -> bool:
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, str):
        return raw.strip().lower() not in {"0", "false", "no", "off", ""}
    return bool(raw)
