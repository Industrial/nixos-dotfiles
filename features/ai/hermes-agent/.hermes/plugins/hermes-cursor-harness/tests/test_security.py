from __future__ import annotations

import pytest

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.security import apply_security_profile, ensure_background_allowed, ensure_transport_allowed


def test_security_profile_overrides_defaults() -> None:
    cfg = apply_security_profile(HarnessConfig(), "repo-edit")

    assert cfg.security_profile == "repo-edit"
    assert cfg.default_permission_policy == "edit"
    assert "hermes_cursor_status" in cfg.trusted_readonly_mcp_tools


def test_security_profile_can_restrict_transport() -> None:
    cfg = HarnessConfig(
        security_profile="custom",
        security_profiles={"custom": {"allowed_transports": ["acp"], "default_permission_policy": "plan"}},
    )

    ensure_transport_allowed(cfg, "acp")
    with pytest.raises(ValueError, match="not allowed"):
        ensure_transport_allowed(cfg, "stream")


def test_security_profile_blocks_background_agents() -> None:
    cfg = apply_security_profile(HarnessConfig(), "readonly")

    with pytest.raises(ValueError, match="not allowed"):
        ensure_background_allowed(cfg)


def test_custom_security_profile_uses_config_background_default() -> None:
    cfg = apply_security_profile(
        HarnessConfig(
            allow_background_agents=True,
            security_profiles={"custom": {"default_permission_policy": "plan"}},
        ),
        "custom",
    )

    ensure_background_allowed(cfg)


def test_security_profile_coerces_string_background_flag() -> None:
    cfg = apply_security_profile(
        HarnessConfig(
            security_profiles={"custom": {"allow_background_agents": "false"}},
        ),
        "custom",
    )

    with pytest.raises(ValueError, match="not allowed"):
        ensure_background_allowed(cfg)


def test_security_profile_rejects_writeback_tools_as_trusted_readonly() -> None:
    cfg = HarnessConfig(
        security_profiles={
            "custom": {
                "trusted_readonly_mcp_tools": ["hermes_cursor_status", "hermes_cursor_append_event"],
            }
        },
    )

    with pytest.raises(ValueError, match="cannot include writeback tools"):
        apply_security_profile(cfg, "custom")
