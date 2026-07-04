from __future__ import annotations

import json
from io import BytesIO
from urllib.error import HTTPError

import pytest

from hermes_cursor_harness.background import BackgroundAgentClient, BackgroundAgentError


class FakeResponse:
    def __init__(self, payload: dict):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self) -> bytes:
        return json.dumps(self.payload).encode("utf-8")


def test_launch_agent_builds_cursor_background_request(monkeypatch: pytest.MonkeyPatch) -> None:
    captured = {}

    def fake_urlopen(request, timeout, **kwargs):
        captured["url"] = request.full_url
        captured["method"] = request.get_method()
        captured["headers"] = dict(request.header_items())
        captured["body"] = json.loads(request.data.decode("utf-8"))
        captured["timeout"] = timeout
        return FakeResponse({"id": "bc_123", "status": "CREATING"})

    monkeypatch.setattr("hermes_cursor_harness.background.urlopen", fake_urlopen)
    client = BackgroundAgentClient(api_key="secret", timeout_sec=12)

    result = client.launch_agent(
        prompt="Fix docs",
        repository="https://github.com/example/repo",
        ref="main",
        model="claude-4-sonnet",
        branch_name="cursor/fix-docs",
        auto_create_pr=True,
    )

    assert result["id"] == "bc_123"
    assert captured["url"] == "https://api.cursor.com/v0/agents"
    assert captured["method"] == "POST"
    assert captured["headers"]["Authorization"] == "Bearer secret"
    assert captured["timeout"] == 12
    assert captured["body"]["prompt"]["text"] == "Fix docs"
    assert captured["body"]["source"] == {"repository": "https://github.com/example/repo", "ref": "main"}
    assert captured["body"]["target"] == {"autoCreatePr": True, "branchName": "cursor/fix-docs"}


def test_background_client_surfaces_http_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_urlopen(request, timeout, **kwargs):
        raise HTTPError(request.full_url, 401, "Unauthorized", {}, BytesIO(b'{"error":"bad key"}'))

    monkeypatch.setattr("hermes_cursor_harness.background.urlopen", fake_urlopen)
    client = BackgroundAgentClient(api_key="bad")

    with pytest.raises(BackgroundAgentError, match="401"):
        client.list_agents()


def test_api_key_info_uses_me_endpoint(monkeypatch: pytest.MonkeyPatch) -> None:
    captured = {}

    def fake_urlopen(request, timeout, **kwargs):
        captured["url"] = request.full_url
        captured["method"] = request.get_method()
        return FakeResponse({"apiKeyName": "Smoke", "userEmail": "user@example.com"})

    monkeypatch.setattr("hermes_cursor_harness.background.urlopen", fake_urlopen)
    client = BackgroundAgentClient(api_key="secret")

    result = client.api_key_info()

    assert captured["url"] == "https://api.cursor.com/v0/me"
    assert captured["method"] == "GET"
    assert result["apiKeyName"] == "Smoke"
