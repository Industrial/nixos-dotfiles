from __future__ import annotations

from hermes_cursor_harness.child_env import cursor_child_env


def test_cursor_child_env_does_not_inherit_provider_or_gateway_secrets(monkeypatch) -> None:
    monkeypatch.setenv("PATH", "/usr/bin")
    monkeypatch.setenv("HOME", "/tmp/home")
    monkeypatch.setenv("CURSOR_API_KEY", "crsr_test")
    monkeypatch.setenv("OPENAI_API_KEY", "openai-secret")
    monkeypatch.setenv("GITHUB_TOKEN", "github-secret")
    monkeypatch.setenv("HERMES_GATEWAY_TOKEN", "gateway-secret")

    env = cursor_child_env(extra={"HERMES_CURSOR_HARNESS_SDK_NODE_MODULES": "/tmp/sdk"})

    assert env["PATH"] == "/usr/bin"
    assert env["HOME"] == "/tmp/home"
    assert env["CURSOR_API_KEY"] == "crsr_test"
    assert env["HERMES_CURSOR_HARNESS_SDK_NODE_MODULES"] == "/tmp/sdk"
    assert "OPENAI_API_KEY" not in env
    assert "GITHUB_TOKEN" not in env
    assert "HERMES_GATEWAY_TOKEN" not in env


def test_cursor_child_env_can_pass_fake_test_controls(monkeypatch) -> None:
    monkeypatch.setenv("FAKE_STREAM_STDERR", "1")
    monkeypatch.setenv("EXPECT_CURSOR_MODE", "plan")

    without_tests = cursor_child_env(include_test_controls=False)
    with_tests = cursor_child_env(include_test_controls=True)

    assert "FAKE_STREAM_STDERR" not in without_tests
    assert "EXPECT_CURSOR_MODE" not in without_tests
    assert with_tests["FAKE_STREAM_STDERR"] == "1"
    assert with_tests["EXPECT_CURSOR_MODE"] == "plan"
