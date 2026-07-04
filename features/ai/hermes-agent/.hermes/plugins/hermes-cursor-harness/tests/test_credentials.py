from __future__ import annotations

import subprocess

from hermes_cursor_harness.credentials import (
    background_key_status,
    delete_background_key_from_keychain,
    read_background_key_from_keychain,
    redact_secret,
    resolve_background_api_key,
    store_background_key_in_keychain,
)


def test_background_key_status_prefers_environment(monkeypatch) -> None:
    monkeypatch.setenv("CURSOR_BACKGROUND_API_KEY", "cur_bg_123456789")

    status = background_key_status(include_key=True)

    assert status.available is True
    assert status.source == "CURSOR_BACKGROUND_API_KEY"
    assert status.fingerprint == "cur_...6789"
    assert resolve_background_api_key() == "cur_bg_123456789"


def test_redact_secret_handles_short_values() -> None:
    assert redact_secret("secret") == "******"


def test_keychain_store_read_and_delete(monkeypatch) -> None:
    calls = []

    def fake_run(command, **kwargs):
        calls.append(command)
        if command[1] == "find-generic-password":
            return subprocess.CompletedProcess(command, 0, stdout="cur_bg_abcdef1234\n", stderr="")
        return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    monkeypatch.setattr("hermes_cursor_harness.credentials.shutil.which", lambda name: "/usr/bin/security")
    monkeypatch.setattr("hermes_cursor_harness.credentials.subprocess.run", fake_run)

    store_background_key_in_keychain("cur_bg_abcdef1234", account="tester")
    assert read_background_key_from_keychain(account="tester") == "cur_bg_abcdef1234"
    assert delete_background_key_from_keychain(account="tester") is True
    assert calls[0][:3] == ["security", "add-generic-password", "-a"]
    assert "-U" in calls[0]
