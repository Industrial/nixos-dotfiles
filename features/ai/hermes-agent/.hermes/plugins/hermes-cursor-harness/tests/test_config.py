from __future__ import annotations

import json
from pathlib import Path

import pytest

from hermes_cursor_harness.config import (
    DEFAULT_APPROVAL_BRIDGE_COMMAND,
    HarnessConfig,
    load_config,
    resolve_acp_command,
    resolve_stream_command,
)
from hermes_cursor_harness.config_validator import validate_config


def test_config_rejects_file_project_alias(tmp_path: Path) -> None:
    project_file = tmp_path / "not-a-dir"
    project_file.write_text("x", encoding="utf-8")
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"projects": {"bad": str(project_file)}}), encoding="utf-8")

    cfg = load_config(config_path)

    with pytest.raises(ValueError, match="not a directory"):
        cfg.resolve_project("bad")


def test_config_parses_false_string_for_project_paths(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"allow_project_paths": "false"}), encoding="utf-8")

    cfg = load_config(config_path)

    with pytest.raises(ValueError, match="unknown project"):
        cfg.resolve_project(str(project))


def test_config_uses_default_approval_bridge_command(tmp_path: Path) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")

    cfg = load_config(config_path)

    assert cfg.approval_bridge_command == DEFAULT_APPROVAL_BRIDGE_COMMAND


def test_config_parses_trusted_readonly_mcp_tools(tmp_path: Path) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(
        json.dumps(
            {
                "trusted_readonly_mcp_tools": ["hermes_cursor_status"],
                "background_api_base_url": "https://example.test/",
                "sdk_command": "node bridge.mjs",
                "sdk_runtime": "cloud",
                "sdk_auto_install": "false",
                "sdk_setting_sources": ["project"],
                "sdk_cloud_repository": "https://github.com/example/repo",
                "security_profile": "readonly",
                "security_profiles": {"locked": {"allowed_transports": ["acp"]}},
                "approval_bridge_command": "python bridge.py",
            }
        ),
        encoding="utf-8",
    )

    cfg = load_config(config_path)

    assert cfg.trusted_readonly_mcp_tools == ["hermes_cursor_status"]
    assert cfg.background_api_base_url == "https://example.test"
    assert cfg.sdk_command == ["node", "bridge.mjs"]
    assert cfg.sdk_runtime == "cloud"
    assert cfg.sdk_auto_install is False
    assert cfg.sdk_setting_sources == ["project"]
    assert cfg.sdk_cloud_repository == "https://github.com/example/repo"
    assert cfg.security_profile == "readonly"
    assert cfg.security_profiles["locked"]["allowed_transports"] == ["acp"]
    assert cfg.approval_bridge_command == ["python", "bridge.py"]


def test_config_allows_env_override_for_sdk_sandbox(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"sdk_sandbox_enabled": True}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED", "false")

    cfg = load_config(config_path)

    assert cfg.sdk_sandbox_enabled is False


def test_config_rejects_writeback_tools_as_trusted_readonly(tmp_path: Path) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(
        json.dumps({"trusted_readonly_mcp_tools": ["hermes_cursor_status", "hermes_cursor_propose"]}),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="cannot include writeback tools"):
        load_config(config_path)


def test_cursor_agent_command_discovery_checks_local_bin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fake_home = tmp_path / "home"
    local_bin = fake_home / ".local" / "bin"
    local_bin.mkdir(parents=True)
    agent = local_bin / "agent"
    agent.write_text("#!/usr/bin/env bash\necho fake-agent\n", encoding="utf-8")
    agent.chmod(0o755)
    monkeypatch.setenv("HOME", str(fake_home))
    monkeypatch.setattr("hermes_cursor_harness.config.shutil.which", lambda name: None)

    assert resolve_acp_command(HarnessConfig()) == [str(agent), "acp"]
    assert resolve_stream_command(HarnessConfig()) == [str(agent)]


def test_config_validation_finds_companion_wrapper_in_local_bin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fake_home = tmp_path / "home"
    local_bin = fake_home / ".local" / "bin"
    local_bin.mkdir(parents=True)
    wrapper = local_bin / "hermes-cursor-harness-mcp"
    wrapper.write_text("#!/usr/bin/env bash\necho fake-wrapper\n", encoding="utf-8")
    wrapper.chmod(0o755)
    state_dir = tmp_path / "state"
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(
        json.dumps(
            {
                "state_dir": str(state_dir),
                "sdk_command": "fake-sdk",
                "acp_command": "fake-acp",
                "stream_command": "fake-stream",
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("HOME", str(fake_home))
    monkeypatch.setattr("hermes_cursor_harness.config.shutil.which", lambda name: None)

    result = validate_config(config_path, include_sdk_status=False)

    companion_check = next(check for check in result["checks"] if check["name"] == "companion.mcp_wrapper")
    assert companion_check["status"] == "pass"
    assert companion_check["detail"] == str(wrapper)


def test_config_validation_finds_default_approval_bridge_in_local_bin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fake_home = tmp_path / "home"
    local_bin = fake_home / ".local" / "bin"
    local_bin.mkdir(parents=True)
    bridge = local_bin / "hermes-cursor-harness"
    bridge.write_text("#!/usr/bin/env bash\necho fake-bridge\n", encoding="utf-8")
    bridge.chmod(0o755)
    state_dir = tmp_path / "state"
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(
        json.dumps(
            {
                "state_dir": str(state_dir),
                "sdk_command": "fake-sdk",
                "acp_command": "fake-acp",
                "stream_command": "fake-stream",
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("HOME", str(fake_home))
    monkeypatch.setattr("hermes_cursor_harness.config.shutil.which", lambda name: None)

    result = validate_config(config_path, include_sdk_status=False)

    bridge_check = next(check for check in result["checks"] if check["name"] == "approval_bridge.command")
    assert bridge_check["status"] == "pass"
    assert bridge_check["detail"]["command"] == DEFAULT_APPROVAL_BRIDGE_COMMAND
    assert bridge_check["detail"]["resolved"] == str(bridge)
