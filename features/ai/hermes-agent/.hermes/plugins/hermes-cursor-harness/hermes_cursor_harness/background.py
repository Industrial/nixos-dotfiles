"""Cursor Background Agents API client.

This is intentionally a thin standard-library wrapper around Cursor's public
Background Agents API. Hermes remains the outer runtime; background agents are
an optional remote execution lane for long-running repository work.
"""

from __future__ import annotations

import json
import os
import ssl
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .config import HarnessConfig
from .credentials import resolve_background_api_key


class BackgroundAgentError(RuntimeError):
    """Raised when the Cursor Background Agents API cannot complete a request."""


def background_api_key() -> str | None:
    return os.environ.get("CURSOR_BACKGROUND_API_KEY") or os.environ.get("CURSOR_API_KEY") or resolve_background_api_key()


class BackgroundAgentClient:
    def __init__(self, *, api_key: str, base_url: str = "https://api.cursor.com", timeout_sec: float = 30.0):
        if not api_key:
            raise BackgroundAgentError("Cursor Background Agents API key is required")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout_sec = timeout_sec

    def launch_agent(
        self,
        *,
        prompt: str,
        repository: str,
        ref: str | None = None,
        model: str | None = None,
        branch_name: str | None = None,
        auto_create_pr: bool = False,
        webhook_url: str | None = None,
        webhook_secret: str | None = None,
        images: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "prompt": _prompt_payload(prompt, images),
            "source": {"repository": repository},
            "target": {"autoCreatePr": bool(auto_create_pr)},
        }
        if ref:
            body["source"]["ref"] = ref
        if model:
            body["model"] = model
        if branch_name:
            body["target"]["branchName"] = branch_name
        if webhook_url:
            body["webhook"] = {"url": webhook_url}
            if webhook_secret:
                body["webhook"]["secret"] = webhook_secret
        return self._request("POST", "/v0/agents", body=body)

    def list_agents(self, *, limit: int = 20, cursor: str | None = None) -> dict[str, Any]:
        params: dict[str, Any] = {"limit": int(limit)}
        if cursor:
            params["cursor"] = cursor
        return self._request("GET", "/v0/agents", query=params)

    def api_key_info(self) -> dict[str, Any]:
        return self._request("GET", "/v0/me")

    def get_agent(self, agent_id: str) -> dict[str, Any]:
        return self._request("GET", f"/v0/agents/{_require_id(agent_id)}")

    def get_conversation(self, agent_id: str) -> dict[str, Any]:
        return self._request("GET", f"/v0/agents/{_require_id(agent_id)}/conversation")

    def add_followup(
        self,
        *,
        agent_id: str,
        prompt: str,
        images: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        return self._request("POST", f"/v0/agents/{_require_id(agent_id)}/followup", body={"prompt": _prompt_payload(prompt, images)})

    def delete_agent(self, agent_id: str) -> dict[str, Any]:
        return self._request("DELETE", f"/v0/agents/{_require_id(agent_id)}")

    def _request(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        query: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        url = self.base_url + path
        if query:
            url += "?" + urlencode(query)
        data = None
        headers = {"Authorization": f"Bearer {self.api_key}", "Accept": "application/json"}
        if body is not None:
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = Request(url, data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=self.timeout_sec, context=_ssl_context()) as response:
                payload = response.read().decode("utf-8")
                return json.loads(payload) if payload.strip() else {"success": True}
        except HTTPError as exc:
            payload = exc.read().decode("utf-8", errors="replace")
            detail = _parse_error_payload(payload)
            raise BackgroundAgentError(f"Cursor Background Agents API {method} {path} failed with {exc.code}: {detail}") from exc
        except URLError as exc:
            raise BackgroundAgentError(f"Cursor Background Agents API {method} {path} failed: {exc.reason}") from exc


def client_from_config(cfg: HarnessConfig, *, api_key: str | None = None, timeout_sec: float = 30.0) -> BackgroundAgentClient:
    return BackgroundAgentClient(
        api_key=api_key or background_api_key() or "",
        base_url=cfg.background_api_base_url,
        timeout_sec=timeout_sec,
    )


def _prompt_payload(text: str, images: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    if not text or not text.strip():
        raise ValueError("prompt text is required")
    payload: dict[str, Any] = {"text": text}
    if images:
        payload["images"] = images
    return payload


def _require_id(agent_id: str) -> str:
    agent_id = str(agent_id or "").strip()
    if not agent_id:
        raise ValueError("agent_id is required")
    return agent_id


def _parse_error_payload(payload: str) -> str:
    if not payload.strip():
        return "(empty response)"
    try:
        parsed = json.loads(payload)
    except json.JSONDecodeError:
        return payload.strip()
    if isinstance(parsed, dict):
        for key in ("error", "message", "detail"):
            value = parsed.get(key)
            if value:
                return str(value)
    return json.dumps(parsed, ensure_ascii=False)


def _ssl_context() -> ssl.SSLContext:
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()
