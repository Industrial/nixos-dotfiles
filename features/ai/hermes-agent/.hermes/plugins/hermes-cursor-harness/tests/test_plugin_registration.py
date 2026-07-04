from __future__ import annotations

from hermes_cursor_harness.plugin import register


class FakeContext:
    def __init__(self) -> None:
        self.tools: list[dict] = []
        self.skills: list[dict] = []

    def register_tool(self, **kwargs):
        self.tools.append(kwargs)

    def register_skill(self, name, path, description=""):
        self.skills.append({"name": name, "path": path, "description": description})


def test_registers_harness_tools() -> None:
    ctx = FakeContext()
    register(ctx)
    names = {item["name"] for item in ctx.tools}
    assert names == {
        "cursor_harness_run",
        "cursor_harness_status",
        "cursor_harness_events",
        "cursor_harness_doctor",
        "cursor_harness_models",
        "cursor_harness_sdk",
        "cursor_harness_latest",
        "cursor_harness_install_companion",
        "cursor_harness_smoke",
        "cursor_harness_background_agent",
        "cursor_harness_provider_route",
        "cursor_harness_diagnostics",
        "cursor_harness_compatibility",
        "cursor_harness_config",
        "cursor_harness_session",
        "cursor_harness_security_profiles",
        "cursor_harness_approvals",
        "cursor_harness_proposals",
        "cursor_harness_proposal_inbox",
    }
    assert all(item["toolset"] == "cursor_harness" for item in ctx.tools)
    assert ctx.skills[0]["name"] == "cursor-harness"
    assert ctx.skills[0]["path"].exists()
