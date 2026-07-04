"""Configuration and command discovery for the Hermes Cursor harness."""

from __future__ import annotations

import json
import os
import shlex
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


TRANSPORTS = {"auto", "sdk", "acp", "stream"}
SDK_RUNTIMES = {"local", "cloud"}
PERMISSION_POLICIES = {"plan", "ask", "edit", "full_access", "reject"}
DEFAULT_TRUSTED_READONLY_MCP_TOOLS = [
    "hermes_cursor_events",
    "hermes_cursor_latest",
    "hermes_cursor_project_context",
    "hermes_cursor_sdk_status",
    "hermes_cursor_status",
]
WRITEBACK_MCP_TOOLS = {
    "hermes_cursor_append_event",
    "hermes_cursor_propose",
}
DEFAULT_APPROVAL_BRIDGE_COMMAND = ["hermes-cursor-harness", "approval-bridge"]


@dataclass
class HarnessConfig:
    """Runtime configuration loaded from JSON and environment variables."""

    transport: str = "auto"
    sdk_command: list[str] = field(default_factory=list)
    sdk_runtime: str = "local"
    sdk_package: str = "@cursor/sdk@latest"
    sdk_auto_install: bool = True
    sdk_node_dir: Path | None = None
    sdk_setting_sources: list[str] = field(default_factory=lambda: ["project", "user", "team", "plugins"])
    sdk_sandbox_enabled: bool = True
    sdk_cloud_repository: str | None = None
    sdk_cloud_ref: str | None = None
    sdk_auto_create_pr: bool = False
    acp_command: list[str] = field(default_factory=list)
    stream_command: list[str] = field(default_factory=list)
    projects: dict[str, str] = field(default_factory=dict)
    mcp_servers: list[dict[str, Any]] = field(default_factory=list)
    state_dir: Path = field(default_factory=lambda: default_state_dir())
    default_timeout_sec: float = 900.0
    no_output_timeout_sec: float = 120.0
    default_permission_policy: str = "plan"
    default_model: str | None = None
    max_events_per_result: int = 80
    allow_project_paths: bool = True
    trusted_readonly_mcp_tools: list[str] = field(default_factory=lambda: list(DEFAULT_TRUSTED_READONLY_MCP_TOOLS))
    background_api_base_url: str = "https://api.cursor.com"
    allow_background_agents: bool = True
    security_profile: str | None = None
    security_profiles: dict[str, dict[str, Any]] = field(default_factory=dict)
    approval_bridge_command: list[str] = field(default_factory=lambda: list(DEFAULT_APPROVAL_BRIDGE_COMMAND))
    approval_bridge_timeout_sec: float = 120.0

    def resolve_project(self, project: str) -> Path:
        if not project:
            raise ValueError("project is required")
        if project in self.projects:
            return _validate_project_dir(Path(self.projects[project]).expanduser().resolve(), project)
        lowered = project.lower()
        for name, path in self.projects.items():
            if name.lower() == lowered:
                return _validate_project_dir(Path(path).expanduser().resolve(), name)
        candidate = Path(project).expanduser()
        if self.allow_project_paths and candidate.exists():
            return _validate_project_dir(candidate.resolve(), project)
        known = ", ".join(sorted(self.projects)) or "none"
        raise ValueError(f"unknown project {project!r}; configured aliases: {known}")


def default_hermes_home() -> Path:
    return Path(os.environ.get("HERMES_HOME", "~/.hermes")).expanduser()


def default_state_dir() -> Path:
    override = os.environ.get("HERMES_CURSOR_HARNESS_HOME")
    if override:
        return Path(override).expanduser()
    return default_hermes_home() / "cursor_harness"


def default_config_path() -> Path:
    override = os.environ.get("HERMES_CURSOR_HARNESS_CONFIG")
    if override:
        return Path(override).expanduser()
    return default_hermes_home() / "cursor_harness.json"


def load_config(path: str | Path | None = None) -> HarnessConfig:
    """Load harness configuration from JSON with environment overrides."""

    cfg_path = Path(path).expanduser() if path else default_config_path()
    raw: dict[str, Any] = {}
    if cfg_path.exists():
        with cfg_path.open("r", encoding="utf-8") as handle:
            loaded = json.load(handle)
        if not isinstance(loaded, dict):
            raise ValueError(f"{cfg_path} must contain a JSON object")
        raw = loaded

    transport = str(os.environ.get("HERMES_CURSOR_HARNESS_TRANSPORT", raw.get("transport", "auto"))).lower()
    if transport not in TRANSPORTS:
        raise ValueError(f"transport must be one of {sorted(TRANSPORTS)}")

    sdk_runtime = str(os.environ.get("HERMES_CURSOR_HARNESS_SDK_RUNTIME", raw.get("sdk_runtime", "local"))).lower()
    if sdk_runtime not in SDK_RUNTIMES:
        raise ValueError(f"sdk_runtime must be one of {sorted(SDK_RUNTIMES)}")

    permission = str(raw.get("default_permission_policy", "plan")).lower()
    if permission not in PERMISSION_POLICIES:
        raise ValueError(f"default_permission_policy must be one of {sorted(PERMISSION_POLICIES)}")

    state_dir_raw = raw.get("state_dir")
    state_dir = Path(state_dir_raw).expanduser() if state_dir_raw else default_state_dir()

    trusted_readonly_mcp_tools = _string_list(
        raw.get("trusted_readonly_mcp_tools", DEFAULT_TRUSTED_READONLY_MCP_TOOLS),
        "trusted_readonly_mcp_tools",
    )
    unsafe_trusted = sorted(set(trusted_readonly_mcp_tools).intersection(WRITEBACK_MCP_TOOLS))
    if unsafe_trusted:
        raise ValueError(
            "trusted_readonly_mcp_tools cannot include writeback tools: " + ", ".join(unsafe_trusted)
        )

    cfg = HarnessConfig(
        transport=transport,
        sdk_command=_command_from_env_or_raw("HERMES_CURSOR_HARNESS_SDK_COMMAND", raw.get("sdk_command")),
        sdk_runtime=sdk_runtime,
        sdk_package=str(os.environ.get("HERMES_CURSOR_HARNESS_SDK_PACKAGE", raw.get("sdk_package", "@cursor/sdk@latest"))),
        sdk_auto_install=_coerce_bool(raw.get("sdk_auto_install", True)),
        sdk_node_dir=Path(raw["sdk_node_dir"]).expanduser() if raw.get("sdk_node_dir") else None,
        sdk_setting_sources=_string_list(raw.get("sdk_setting_sources", ["project", "user", "team", "plugins"]), "sdk_setting_sources"),
        sdk_sandbox_enabled=_coerce_bool(
            os.environ.get("HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED", raw.get("sdk_sandbox_enabled", True))
        ),
        sdk_cloud_repository=str(
            os.environ.get("HERMES_CURSOR_HARNESS_SDK_CLOUD_REPOSITORY", raw.get("sdk_cloud_repository", ""))
        ).strip()
        or None,
        sdk_cloud_ref=str(os.environ.get("HERMES_CURSOR_HARNESS_SDK_CLOUD_REF", raw.get("sdk_cloud_ref", ""))).strip()
        or None,
        sdk_auto_create_pr=_coerce_bool(raw.get("sdk_auto_create_pr", False)),
        acp_command=_command_from_env_or_raw("HERMES_CURSOR_HARNESS_ACP_COMMAND", raw.get("acp_command")),
        stream_command=_command_from_env_or_raw("HERMES_CURSOR_HARNESS_STREAM_COMMAND", raw.get("stream_command")),
        projects=_string_map(raw.get("projects", {})),
        mcp_servers=list(raw.get("mcp_servers", [])),
        state_dir=state_dir,
        default_timeout_sec=_positive_float(raw.get("default_timeout_sec", 900.0), "default_timeout_sec"),
        no_output_timeout_sec=_positive_float(raw.get("no_output_timeout_sec", 120.0), "no_output_timeout_sec"),
        default_permission_policy=permission,
        default_model=raw.get("default_model"),
        max_events_per_result=_bounded_int(raw.get("max_events_per_result", 80), "max_events_per_result", minimum=-1),
        allow_project_paths=_coerce_bool(raw.get("allow_project_paths", True)),
        trusted_readonly_mcp_tools=trusted_readonly_mcp_tools,
        background_api_base_url=str(raw.get("background_api_base_url", "https://api.cursor.com")).rstrip("/"),
        allow_background_agents=_coerce_bool(raw.get("allow_background_agents", True)),
        security_profile=str(raw.get("security_profile") or "").strip() or None,
        security_profiles=_profile_map(raw.get("security_profiles", {})),
        approval_bridge_command=_command_from_env_or_raw(
            "HERMES_CURSOR_HARNESS_APPROVAL_BRIDGE",
            raw.get("approval_bridge_command", DEFAULT_APPROVAL_BRIDGE_COMMAND),
        ),
        approval_bridge_timeout_sec=_positive_float(raw.get("approval_bridge_timeout_sec", 120.0), "approval_bridge_timeout_sec"),
    )
    cfg.state_dir.mkdir(parents=True, exist_ok=True)
    (cfg.state_dir / "events").mkdir(parents=True, exist_ok=True)
    return cfg


def resolve_sdk_command(cfg: HarnessConfig) -> list[str]:
    """Resolve the command that runs the Cursor SDK bridge."""

    if cfg.sdk_command:
        return list(cfg.sdk_command)
    node = find_executable("node")
    if node:
        return [node, str(Path(__file__).with_name("sdk_bridge.mjs"))]
    raise FileNotFoundError("could not find Node.js for Cursor SDK bridge; set HERMES_CURSOR_HARNESS_SDK_COMMAND")


def resolve_acp_command(cfg: HarnessConfig) -> list[str]:
    """Resolve the command that starts Cursor's ACP server."""

    if cfg.acp_command:
        return list(cfg.acp_command)
    agent = find_executable("agent")
    if agent:
        return [agent, "acp"]
    cursor_agent = find_executable("cursor-agent")
    if cursor_agent:
        return [cursor_agent, "acp"]
    cursor = find_executable("cursor")
    if cursor:
        return [cursor, "agent", "acp"]
    raise FileNotFoundError("could not find Cursor ACP command; set HERMES_CURSOR_HARNESS_ACP_COMMAND")


def resolve_stream_command(cfg: HarnessConfig) -> list[str]:
    """Resolve the command prefix for Cursor stream-json execution."""

    if cfg.stream_command:
        return list(cfg.stream_command)
    agent = find_executable("agent")
    if agent:
        return [agent]
    cursor_agent = find_executable("cursor-agent")
    if cursor_agent:
        return [cursor_agent]
    cursor = find_executable("cursor")
    if cursor:
        return [cursor, "agent"]
    raise FileNotFoundError("could not find Cursor Agent command; set HERMES_CURSOR_HARNESS_STREAM_COMMAND")


def find_executable(name: str) -> str | None:
    """Find a command in PATH plus common GUI-app install locations."""

    found = shutil.which(name)
    if found:
        return found
    home = Path(os.environ.get("HOME", "~")).expanduser()
    for directory in (home / ".local" / "bin", Path("/opt/homebrew/bin"), Path("/usr/local/bin")):
        candidate = directory / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _command_from_env_or_raw(env_name: str, raw: Any) -> list[str]:
    env_value = os.environ.get(env_name)
    if env_value:
        return shlex.split(env_value)
    if isinstance(raw, str):
        return shlex.split(raw)
    if isinstance(raw, list):
        return [str(part) for part in raw]
    return []


def _string_map(raw: Any) -> dict[str, str]:
    if not isinstance(raw, dict):
        return {}
    return {str(k): str(v) for k, v in raw.items()}


def _profile_map(raw: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(raw, dict):
        return {}
    profiles: dict[str, dict[str, Any]] = {}
    for key, value in raw.items():
        if isinstance(value, dict):
            profiles[str(key)] = dict(value)
    return profiles


def _string_list(raw: Any, name: str) -> list[str]:
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise ValueError(f"{name} must be a list")
    return [str(item) for item in raw if str(item).strip()]


def _validate_project_dir(path: Path, label: str) -> Path:
    if not path.exists():
        raise ValueError(f"project {label!r} does not exist: {path}")
    if not path.is_dir():
        raise ValueError(f"project {label!r} is not a directory: {path}")
    return path


def _positive_float(raw: Any, name: str) -> float:
    value = float(raw)
    if value <= 0:
        raise ValueError(f"{name} must be positive")
    return value


def _bounded_int(raw: Any, name: str, *, minimum: int) -> int:
    value = int(raw)
    if value < minimum:
        raise ValueError(f"{name} must be >= {minimum}")
    return value


def _coerce_bool(raw: Any) -> bool:
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, str):
        return raw.strip().lower() not in {"0", "false", "no", "off", ""}
    return bool(raw)
